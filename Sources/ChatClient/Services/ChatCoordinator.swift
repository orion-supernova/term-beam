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

    func start(username: String) async throws {
        await presenter.showWelcomeUser(username: username)

        while true {
            try await showRoomSelectionAndJoin(username: username)
        }
    }

    func cleanup() async {
        if let session = currentSession {
            await session.stop()
        }
    }

    private func showRoomSelectionAndJoin(username: String) async throws {
        // Fetch and display rooms
        await presenter.showInfo("Fetching available rooms...")

        do {
            let rooms = try await roomService.listRooms()
            await presenter.showRooms(rooms)
        } catch {
            await presenter.showError("Failed to fetch rooms: \(error.localizedDescription)")
            throw error
        }

        // Get user choice
        let choice = await getUserRoomChoice()

        // Create or join room
        let (roomId, joinResponse) = try await handleRoomChoice(
            choice: choice,
            username: username
        )

        // Show room info
        await presenter.showJoinedRoom(room: joinResponse, currentUsername: username)

        // Start chat session
        try await startChatSession(
            roomId: roomId,
            userId: joinResponse.userId,
            username: username,
            roomName: joinResponse.room.name
        )
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

    private func handleRoomChoice(
        choice: String,
        username: String
    ) async throws -> (roomId: String, response: JoinRoomResponse) {
        if choice.hasPrefix("c") {
            return try await roomService.createAndJoinRoom(username: username)
        } else {
            return try await roomService.joinExistingRoom(username: username)
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
