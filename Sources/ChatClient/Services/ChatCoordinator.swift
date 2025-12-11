import Foundation

// MARK: - Chat Coordinator
/// Main coordinator for the chat application
/// Follows Single Responsibility: Application flow coordination

actor ChatCoordinator {
    private let apiClient: ChatAPIClientProtocol
    private let roomService: RoomService
    private let connectionService: ConnectionService
    private let presenter: UIPresenter
    private let input: InputReaderProtocol
    private let config: AppConfiguration
    private let serverURL: String

    private var currentSession: ChatSessionService?

    init(
        serverURL: String,
        apiClient: ChatAPIClientProtocol,
        roomService: RoomService,
        connectionService: ConnectionService,
        presenter: UIPresenter,
        input: InputReaderProtocol,
        config: AppConfiguration
    ) {
        self.serverURL = serverURL
        self.apiClient = apiClient
        self.roomService = roomService
        self.connectionService = connectionService
        self.presenter = presenter
        self.input = input
        self.config = config
    }

    func start() async throws {
        while true {
            do {
                try await showRoomSelectionAndJoin()
            } catch {
                // Don't exit - show error and let user try again
                await presenter.showError("An error occurred: \(error.localizedDescription)")
                await presenter.showInfo("Let's try again...")
                try await Task.sleep(for: .seconds(1))
                // Loop continues, user can try again
            }
        }
    }

    func cleanup() async {
        if let session = currentSession {
            await session.stop()
        }
    }

    private func showRoomSelectionAndJoin() async throws {
        // Fetch and display rooms
        await presenter.showInfo("Fetching available rooms...")

        let rooms: [RoomResponse]
        do {
            rooms = try await roomService.listRooms()
            await presenter.showRooms(rooms)
        } catch {
            await presenter.showError("Failed to fetch rooms: \(error.localizedDescription)")
            // Don't throw - return and let outer loop retry
            return
        }

        // Get user choice (create or join)
        let choice = await getUserRoomChoice()

        // Get room ID and password (but NOT username yet)
        let roomId: String
        let password: String?
        do {
            (roomId, password) = try await getRoomIdAndPassword(choice: choice)
        } catch {
            await presenter.showError("Failed to get room details: \(error.localizedDescription)")
            // Don't throw - return and let outer loop retry
            return
        }

        // Try to join with username (retry if username exists)
        let username: String
        let joinResponse: JoinRoomResponse
        do {
            (username, joinResponse) = try await joinWithUsernameRetry(
                choice: choice,
                roomId: roomId,
                password: password
            )
        } catch {
            await presenter.showError("Failed to join room: \(error.localizedDescription)")
            // Don't throw - return and let outer loop retry
            return
        }

        // Show room info
        await presenter.showJoinedRoom(room: joinResponse, currentUsername: username)

        // Start chat session
        do {
            try await startChatSession(
                roomId: roomId,
                userId: joinResponse.userId,
                username: username,
                roomName: joinResponse.room.name
            )
        } catch {
            await presenter.showError("Chat session error: \(error.localizedDescription)")
            // Don't throw - return and let outer loop retry
            return
        }
    }

    private func getUserRoomChoice() async -> String {
        while true {
            let input = await input.readLine(
                prompt: "Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: "
            )
            let choice = input.lowercased()

            if choice.hasPrefix("c") || choice.hasPrefix("j") {
                return choice
            }

            await presenter.showError("Invalid choice. Please enter 'c' to create or 'j' to join.")
        }
    }

    private func getRoomIdAndPassword(choice: String) async throws -> (roomId: String, password: String?) {
        if choice.hasPrefix("c") {
            // Creating a new room
            let name = await input.readLine(prompt: "Enter room name: ")
            guard !name.isEmpty else {
                await presenter.showError("Room name cannot be empty")
                throw ChatError.invalidInput("Room name cannot be empty")
            }

            let password = await input.readSecureLine(prompt: "Enter password (leave empty for no password): ")
            let finalPassword = password.isEmpty ? nil : password

            await presenter.showInfo("Creating room...")
            let room = try await roomService.createRoom(name: name, password: finalPassword)
            await presenter.showSuccess("Room created: \(room.name)")

            return (room.id, finalPassword)
        } else {
            // Joining existing room
            let roomId = await input.readLine(prompt: "Enter room ID: ")
            guard !roomId.isEmpty else {
                await presenter.showError("Room ID cannot be empty")
                throw ChatError.invalidInput("Room ID cannot be empty")
            }

            // Verify room exists BEFORE asking for password
            await presenter.showInfo("Verifying room...")
            do {
                _ = try await roomService.getRoomInfo(roomId: roomId)
            } catch {
                await presenter.showError("Room not found or invalid room ID")
                throw ChatError.serverError("Invalid room ID")
            }

            let password = await input.readSecureLine(prompt: "Enter room password (if any): ")
            let finalPassword = password.isEmpty ? nil : password

            return (roomId, finalPassword)
        }
    }

    private func getUsername(isRetry: Bool = false) async -> String {
        while true {
            let prompt = isRetry
                ? "That username is taken. Enter a different username for this room: "
                : "Enter your username for this room: "

            let username = await input.readLine(prompt: prompt)
            if !username.isEmpty {
                return username
            }
            await presenter.showError("Username cannot be empty")
        }
    }

    private func joinWithUsernameRetry(
        choice: String,
        roomId: String,
        password: String?
    ) async throws -> (username: String, response: JoinRoomResponse) {
        var isRetry = false

        while true {
            // Ask for username
            let username = await getUsername(isRetry: isRetry)

            // Try to join
            do {
                await presenter.showInfo("Joining room as @\(username)...")
                let joinResponse = try await roomService.joinRoom(
                    roomId: roomId,
                    username: username,
                    password: password
                )
                return (username, joinResponse)
            } catch let error as ChatError {
                // Check if it's a username conflict error
                if case .serverError(let message) = error,
                   message.lowercased().contains("username") &&
                   message.lowercased().contains("exists") {
                    // Username already exists, try again
                    await presenter.showError("Username '\(username)' is already taken in this room.")
                    isRetry = true
                    continue
                }
                // Other errors should be thrown
                throw error
            } catch {
                // Non-ChatError exceptions
                throw error
            }
        }
    }

    private func startChatSession(
        roomId: String,
        userId: String,
        username: String,
        roomName: String
    ) async throws {
        let webSocketClient = WebSocketClient(serverURL: serverURL)

        let session = ChatSessionService(
            webSocketClient: webSocketClient,
            roomService: roomService,
            presenter: presenter,
            input: input,
            roomId: roomId,
            userId: userId,
            username: username,
            roomName: roomName
        )

        currentSession = session
        try await session.start()
        currentSession = nil
    }
}
