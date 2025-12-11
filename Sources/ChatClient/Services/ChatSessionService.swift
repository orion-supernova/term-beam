import Foundation

// MARK: - Chat Session Service
/// Manages active chat session with WebSocket connection
/// Single Responsibility: Chat session lifecycle

actor ChatSessionService {
    private let webSocketClient: WebSocketClientProtocol
    private let roomService: RoomService
    private let presenter: UIPresenter
    private let input: InputReaderProtocol

    private let roomId: String
    private let userId: String
    private let username: String
    private let roomName: String

    private var messageHistory: [Message] = []
    private var isActive = true

    init(
        webSocketClient: WebSocketClientProtocol,
        roomService: RoomService,
        presenter: UIPresenter,
        input: InputReaderProtocol,
        roomId: String,
        userId: String,
        username: String,
        roomName: String
    ) {
        self.webSocketClient = webSocketClient
        self.roomService = roomService
        self.presenter = presenter
        self.input = input
        self.roomId = roomId
        self.userId = userId
        self.username = username
        self.roomName = roomName
    }

    func start() async throws {
        // Fetch and display message history before connecting
        await loadMessageHistory()

        try await webSocketClient.connect(
            roomId: roomId,
            userId: userId,
            onMessage: { [weak self] message in
                Task {
                    await self?.handleMessage(message)
                }
            },
            onDisconnect: { [weak self] in
                Task {
                    await self?.handleDisconnect()
                }
            }
        )

        // Handle user input
        await handleUserInput()
    }

    private func loadMessageHistory() async {
        do {
            let messages = try await roomService.getMessageHistory(roomId: roomId, limit: 50)
            if !messages.isEmpty {
                await presenter.showInfo("Loading recent messages...")
                for message in messages {
                    addToHistory(message)
                    await presenter.showMessage(message, currentUsername: username)
                }
                await presenter.showInfo("End of message history")
                print("") // Empty line for separation
            }
        } catch {
            // If history endpoint doesn't exist or fails, just continue
            // This is not a critical error
        }
    }

    func stop() async {
        isActive = false
        await webSocketClient.disconnect()
    }

    private func handleMessage(_ message: Message) async {
        addToHistory(message)
        await presenter.showMessage(message, currentUsername: username)
    }

    private func handleDisconnect() async {
        if isActive {
            await presenter.showDisconnected()
            isActive = false
        }
    }

    private func handleUserInput() async {
        while isActive {
            let line = await input.readLine(prompt: "\(username) > ")
            guard !line.isEmpty else { continue }

            if line.hasPrefix("/") {
                let shouldExit = await handleCommand(line)
                if shouldExit {
                    break
                }
            } else {
                await sendMessage(line)
            }
        }
    }

    private func sendMessage(_ content: String) async {
        do {
            try await webSocketClient.sendMessage(content)
        } catch {
            await presenter.showError("Failed to send message: \(error.localizedDescription)")
        }
    }

    private func handleCommand(_ command: String) async -> Bool {
        let parts = command.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first?.lowercased() ?? ""

        switch cmd {
        case "help":
            await presenter.showHelp()
            return false

        case "bye", "quit":
            await presenter.showGoodbye()
            await cleanup()
            return true

        case "exit", "leave":
            await cleanup()
            return true

        case "users", "list-users":
            await showUsers()
            return false

        case "rooms", "list-rooms":
            await showRooms()
            return false

        case "info", "room-info":
            await showRoomInfo()
            return false

        case "history":
            await showHistory()
            return false

        default:
            await presenter.showError("Unknown command: /\(cmd)")
            await presenter.showInfo("Type /help to see available commands")
            return false
        }
    }

    private func showUsers() async {
        do {
            let users = try await roomService.getRoomUsers(roomId: roomId)
            await presenter.showUsers(users)
        } catch {
            await presenter.showError("Failed to fetch users: \(error.localizedDescription)")
        }
    }

    private func showRooms() async {
        do {
            let rooms = try await roomService.listRooms()
            await presenter.showRooms(rooms)
        } catch {
            await presenter.showError("Failed to fetch rooms: \(error.localizedDescription)")
        }
    }

    private func showRoomInfo() async {
        do {
            let room = try await roomService.getRoomInfo(roomId: roomId)
            await presenter.showRoomInfo(room)
        } catch {
            await presenter.showError("Failed to fetch room info: \(error.localizedDescription)")
        }
    }

    private func showHistory() async {
        await presenter.showHistory(messageHistory, currentUsername: username)
    }

    private func cleanup() async {
        do {
            try await roomService.leaveRoom(roomId: roomId, userId: userId)
            await webSocketClient.disconnect()
        } catch {
            // Ignore errors during cleanup
        }
    }

    private func addToHistory(_ message: Message) {
        messageHistory.append(message)
        if messageHistory.count > 100 {
            messageHistory.removeFirst(messageHistory.count - 100)
        }
    }
}
