import Foundation
import WebSocketKit
import ArgumentParser
import NIOCore
import NIOPosix

// Thread-safe global cleanup handler
private actor GlobalCleanupHandler {
    static let shared = GlobalCleanupHandler()
    
    private var context: ChatContext?
    
    func setContext(_ context: ChatContext) {
        self.context = context
    }
    
    func cleanup() async {
        await context?.cleanup()
    }
}

@main
struct ChatClient: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat-client",
        abstract: "Terminal chat client for chat servers"
    )
    
    @Option(name: .shortAndLong, help: "Server URL")
    var server: String?
    
    @Option(name: .shortAndLong, help: "Your username")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Room ID to join (optional)")
    var room: String?
    
    func run() async throws {
        print("╔════════════════════════════════════════╗")
        print("║      Terminal Chat Client v1.0        ║")
        print("╚════════════════════════════════════════╝")
        print("")
        
        // Get server address
        let serverURL: String
        if let server = self.server {
            serverURL = normalizeURL(server)
        } else {
            print("Enter the chat server address (or press Enter for localhost:8080):")
            print("  Examples:")
            print("    • localhost:8080 or just press Enter")
            print("    • 192.168.1.100:8080")
            print("    • chat.example.com")
            print("")
            let input = readLine(prompt: "Server [localhost:8080]: ")
            
            if input.isEmpty {
                serverURL = "http://localhost:8080"
                print("Using default: \(serverURL)")
            } else {
                serverURL = normalizeURL(input)
            }
        }
        
        print("\n🌐 Connecting to: \(serverURL)")
        
        let client = ChatAPIClient(baseURL: serverURL)
        
        // Wait for server to be available
        try await waitForServer(client: client, serverURL: serverURL)
        
        print("✅ Server is online\n")
        
        try await runChat(client: client, serverURL: serverURL)
    }
    
    func waitForServer(client: ChatAPIClient, serverURL: String) async throws {
        print("🔍 Checking server connection...")
        
        var attempts = 0
        let maxQuickAttempts = 3
        
        while true {
            let isHealthy = await client.checkHealth()
            
            if isHealthy {
                return
            }
            
            attempts += 1
            
            if attempts == 1 {
                print("⚠️  Cannot connect to server at \(serverURL)")
                print("")
                
                if serverURL.contains("localhost") || serverURL.contains("127.0.0.1") {
                    print("💡 The server is not running. You can:")
                    print("   1. Start the server in another terminal")
                    print("   2. Try a different server address")
                    print("   3. Wait for the server to start (will retry automatically)")
                    print("")
                }
            }
            
            if attempts <= maxQuickAttempts {
                print("🔄 Retrying... (attempt \(attempts)/\(maxQuickAttempts))")
                try await Task.sleep(for: .seconds(2))
            } else {
                print("")
                print("Choose an option:")
                print("  [r] Retry connection")
                print("  [c] Change server address")
                print("  [q] Quit")
                print("")
                
                let choice = readLine(prompt: "Your choice [r/c/q]: ").lowercased()
                
                switch choice {
                case "r", "":
                    print("🔄 Retrying connection...")
                    try await Task.sleep(for: .seconds(1))
                    continue
                    
                case "c":
                    print("")
                    let newURL = readLine(prompt: "Enter new server URL: ")
                    if !newURL.isEmpty {
                        let normalized = normalizeURL(newURL)
                        let newClient = ChatAPIClient(baseURL: normalized)
                        print("🌐 Switching to: \(normalized)")
                        try await waitForServer(client: newClient, serverURL: normalized)
                        return
                    }
                    
                case "q":
                    print("👋 Goodbye!")
                    throw ExitCode.failure
                    
                default:
                    print("❌ Invalid choice. Please enter 'r', 'c', or 'q'")
                    try await Task.sleep(for: .seconds(1))
                }
            }
        }
    }
    
    func runChat(client: ChatAPIClient, serverURL: String) async throws {
        let username = self.username ?? readLine(prompt: "Enter your username: ")
        guard !username.isEmpty else {
            print("❌ Username cannot be empty")
            throw ExitCode.failure
        }
        
        let chatContext = ChatContext(
            client: client,
            serverURL: serverURL,
            username: username
        )
        
        await GlobalCleanupHandler.shared.setContext(chatContext)
        
        // Setup global cleanup on exit
        signal(SIGINT) { _ in
            print("\n\n🛑 Shutting down...")
            Task {
                await GlobalCleanupHandler.shared.cleanup()
                Foundation.exit(0)
            }
        }
        
        try await chatContext.run()
    }
    
    func normalizeURL(_ input: String) -> String {
        var url = input.trimmingCharacters(in: .whitespaces)
        
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }
        
        return url
    }
    
    func readLine(prompt: String, secure: Bool = false) -> String {
        print(prompt, terminator: "")
        fflush(stdout)
        
        if secure {
            var buf = [Int8](repeating: 0, count: 8192)
            guard let ptr = readpassphrase("", &buf, buf.count, 0) else {
                return ""
            }
            return String(cString: ptr)
        } else {
            return Swift.readLine() ?? ""
        }
    }
}

// MARK: - Chat Context (State Management)

class ChatContext: @unchecked Sendable {
    let client: ChatAPIClient
    let serverURL: String
    let username: String
    
    var currentRoomId: String?
    var currentRoomName: String?
    var currentUserId: String?
    var chatSession: ChatSession?
    var messageHistory: [Message] = []
    
    var isInRoom: Bool {
        currentRoomId != nil && currentUserId != nil
    }
    
    init(client: ChatAPIClient, serverURL: String, username: String) {
        self.client = client
        self.serverURL = serverURL
        self.username = username
    }
    
    func run() async throws {
        print("\n💬 Welcome, @\(username)!")
        print("Type /help to see available commands\n")
        
        while true {
            try await showRoomSelectionMenu()
        }
    }
    
    func cleanup() async {
        print("🧹 Cleaning up...")
        if let roomId = currentRoomId, let userId = currentUserId {
            do {
                try await client.leaveRoom(roomId: roomId, userId: userId)
                print("✅ Left all rooms")
            } catch {
                // Ignore errors
            }
        }
        chatSession?.stop()
    }
    
    func showRoomSelectionMenu() async throws {
        print("\n📋 Fetching available rooms...")
        let rooms: [RoomResponse]
        do {
            rooms = try await client.listRooms()
        } catch {
            print("❌ Failed to fetch rooms: \(error.localizedDescription)")
            throw ExitCode.failure
        }
        
        if !rooms.isEmpty {
            print("\n💬 Available rooms:")
            for room in rooms {
                let lock = room.hasPassword ? "🔒" : "🔓"
                print("  \(lock) [\(room.userCount) users] \(room.name)")
                print("     ID: \(room.id)")
            }
            print("")
        } else {
            print("📭 No rooms available.\n")
        }
        
        let choice: String
        while true {
            let input = readLine(prompt: "Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: ").lowercased()
            
            if input.hasPrefix("c") || input.hasPrefix("j") {
                choice = input
                break
            } else {
                print("❌ Invalid choice. Please enter 'c' to create or 'j' to join.")
            }
        }
        
        if choice.hasPrefix("c") {
            try await createAndJoinRoom()
        } else {
            try await joinExistingRoom()
        }
    }
    
    func createAndJoinRoom() async throws {
        let name = readLine(prompt: "Enter room name: ")
        guard !name.isEmpty else {
            print("❌ Room name cannot be empty")
            return
        }
        
        let pwd = readLine(prompt: "Enter password (leave empty for no password): ", secure: true)
        let password = pwd.isEmpty ? nil : pwd
        
        print("\n🔨 Creating room...")
        do {
            let room = try await client.createRoom(name: name, password: password)
            print("✅ Room created: \(room.name)")
            try await joinRoom(roomId: room.id, password: password)
        } catch {
            print("❌ Failed to create room: \(error.localizedDescription)")
        }
    }
    
    func joinExistingRoom() async throws {
        let roomId = readLine(prompt: "Enter room ID: ")
        guard !roomId.isEmpty else {
            print("❌ Room ID cannot be empty")
            return
        }
        
        let pwd = readLine(prompt: "Enter room password (if any): ", secure: true)
        let password = pwd.isEmpty ? nil : pwd
        
        try await joinRoom(roomId: roomId, password: password)
    }
    
    func joinRoom(roomId: String, password: String?) async throws {
        print("\n🚪 Joining room...")
        let joinResponse: JoinRoomResponse
        do {
            joinResponse = try await client.joinRoom(roomId: roomId, username: username, password: password)
        } catch {
            print("❌ Failed to join room: \(error.localizedDescription)")
            return
        }
        
        currentRoomId = roomId
        currentUserId = joinResponse.userId
        currentRoomName = joinResponse.room.name
        messageHistory = []
        
        print("✅ Joined '\(joinResponse.room.name)'")
        
        if joinResponse.users.count > 1 {
            print("👥 Users already in room:")
            for user in joinResponse.users {
                if user.username != username {
                    let timestamp = ChatSession.formatTime(user.joinedAt)
                    print("  [\(timestamp)] → \(user.username) is here")
                }
            }
        } else {
            print("👤 You are the first one here!")
        }
        
        print("\n💬 Loading chat interface...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Room: \(joinResponse.room.name) | User: @\(username)")
        print("Type /help for commands | Type /bye to exit app")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        try await startChatSession()
    }
    
    func startChatSession() async throws {
        guard let roomId = currentRoomId,
              let userId = currentUserId,
              let roomName = currentRoomName else {
            print("❌ Invalid room state")
            return
        }
        
        let session = ChatSession(
            context: self,
            client: client,
            roomId: roomId,
            userId: userId,
            username: username,
            roomName: roomName,
            serverURL: serverURL
        )
        
        chatSession = session
        try await session.start()
    }
    
    func leaveRoom() async {
        guard let roomId = currentRoomId, let userId = currentUserId else {
            print("❌ You're not in a room")
            return
        }
        
        print("\n👋 Leaving room...")
        
        do {
            try await client.leaveRoom(roomId: roomId, userId: userId)
            chatSession?.stop()
            chatSession = nil
            currentRoomId = nil
            currentUserId = nil
            currentRoomName = nil
            messageHistory = []
            print("✅ Left the room")
        } catch {
            print("⚠️  Error leaving room: \(error.localizedDescription)")
        }
    }
    
    func addMessageToHistory(_ message: Message) {
        messageHistory.append(message)
        
        // Keep only last 100 messages
        if messageHistory.count > 100 {
            messageHistory.removeFirst(messageHistory.count - 100)
        }
    }
    
    func readLine(prompt: String, secure: Bool = false) -> String {
        print(prompt, terminator: "")
        fflush(stdout)
        
        if secure {
            var buf = [Int8](repeating: 0, count: 8192)
            guard let ptr = readpassphrase("", &buf, buf.count, 0) else {
                return ""
            }
            return String(cString: ptr)
        } else {
            return Swift.readLine() ?? ""
        }
    }
}

// MARK: - Models

struct RoomResponse: Codable, Sendable {
    let id: String
    let name: String
    let hasPassword: Bool
    let userCount: Int
    let createdAt: String
}

struct CreateRoomRequest: Codable, Sendable {
    let name: String
    let password: String?
}

struct JoinRoomRequest: Codable, Sendable {
    let username: String
    let password: String?
}

struct JoinRoomResponse: Codable, Sendable {
    let userId: String
    let room: RoomResponse
    let users: [UserResponse]
}

struct UserResponse: Codable, Sendable {
    let id: String
    let username: String
    let joinedAt: String
}

struct Message: Codable, Sendable {
    let id: String
    let roomId: String
    let userId: String
    let username: String
    let content: String
    let timestamp: String
    let type: MessageType
}

enum MessageType: String, Codable, Sendable {
    case message
    case userJoined
    case userLeft
    case system
}

struct SendMessageRequest: Codable, Sendable {
    let content: String
}

// MARK: - API Client

actor ChatAPIClient {
    let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func listRooms() async throws -> [RoomResponse] {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([RoomResponse].self, from: data)
    }
    
    func createRoom(name: String, password: String?) async throws -> RoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateRoomRequest(name: name, password: password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ChatError.serverError(error.reason)
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(RoomResponse.self, from: data)
    }
    
    func joinRoom(roomId: String, username: String, password: String?) async throws -> JoinRoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/join") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = JoinRoomRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ChatError.serverError(error.reason)
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(JoinRoomResponse.self, from: data)
    }
    
    func leaveRoom(roomId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/leave/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    func getRoomUsers(roomId: String) async throws -> [UserResponse] {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/users") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([UserResponse].self, from: data)
    }
    
    func getRoomInfo(roomId: String) async throws -> RoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(RoomResponse.self, from: data)
    }
}

struct ErrorResponse: Codable, Sendable {
    let error: Bool
    let reason: String
}

enum ChatError: Error, LocalizedError {
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let msg):
            return msg
        }
    }
}

// MARK: - Chat Session

final class ChatSession: @unchecked Sendable {
    weak var context: ChatContext?
    let client: ChatAPIClient
    let roomId: String
    let userId: String
    let username: String
    let roomName: String
    let serverURL: String
    
    private var ws: WebSocket?
    private var isConnected = false
    private var shouldStop = false
    
    init(context: ChatContext, client: ChatAPIClient, roomId: String, userId: String, username: String, roomName: String, serverURL: String) {
        self.context = context
        self.client = client
        self.roomId = roomId
        self.userId = userId
        self.username = username
        self.roomName = roomName
        self.serverURL = serverURL
    }
    
    func stop() {
        shouldStop = true
        isConnected = false
        ws?.close(code: .normalClosure)
    }
    
    func start() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        let wsURL: String
        if serverURL.starts(with: "https://") {
            wsURL = serverURL.replacingOccurrences(of: "https://", with: "wss://")
        } else {
            wsURL = serverURL.replacingOccurrences(of: "http://", with: "ws://")
        }
        
        let fullWSURL = "\(wsURL)/ws/\(roomId)/\(userId)"
        
        do {
            try await WebSocket.connect(to: fullWSURL, on: eventLoopGroup) { ws in
                self.isConnected = true
                self.ws = ws
                
                let username = self.username
                let roomId = self.roomId
                let userId = self.userId
                let client = self.client
                let context = self.context
                
                ws.onText { _, text in
                    Self.handleMessage(text, username: username, context: context)
                }
                
                ws.onClose.whenComplete { _ in
                    if !self.shouldStop {
                        Self.handleClose(client: client, roomId: roomId, userId: userId)
                    }
                }
                
                Task {
                    await Self.handleUserInput(ws: ws, context: context, client: client, roomId: roomId)
                }
            }.get()
            
            while !shouldStop {
                try await Task.sleep(for: .seconds(1))
            }
        } catch {
            print("❌ Failed to connect to WebSocket: \(error)")
            throw error
        }
    }
    
    private static func handleMessage(_ text: String, username: String, context: ChatContext?) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        
        // Add to history
        context?.addMessageToHistory(message)
        
        let timestamp = formatTime(message.timestamp)
        
        switch message.type {
        case .message:
            if message.username == username {
                print("[\(timestamp)] 💚 You: \(message.content)")
            } else {
                print("[\(timestamp)] 💙 \(message.username): \(message.content)")
            }
        case .userJoined:
            print("[\(timestamp)] → \(message.content)")
        case .userLeft:
            print("[\(timestamp)] ← \(message.content)")
        case .system:
            print("[\(timestamp)] 🔔 [SYSTEM] \(message.content)")
        }
    }
    
    private static func handleUserInput(ws: WebSocket, context: ChatContext?, client: ChatAPIClient, roomId: String) async {
        while true {
            guard let line = readLine(), !line.isEmpty else { continue }
            
            // Check for commands
            if line.hasPrefix("/") {
                let shouldExit = await handleCommand(line, context: context, client: client, roomId: roomId)
                if shouldExit {
                    return
                }
            } else {
                Self.sendMessage(line, ws: ws)
            }
        }
    }
    
    private static func handleCommand(_ command: String, context: ChatContext?, client: ChatAPIClient, roomId: String) async -> Bool {
        let parts = command.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first?.lowercased() ?? ""
        
        switch cmd {
        case "help":
            showHelp()
            return false
            
        case "bye", "quit":
            print("\n👋 Goodbye!")
            if let context = context {
                await context.cleanup()
            }
            Foundation.exit(0)
            
        case "exit", "leave":
            guard let context = context else { return false }
            await context.leaveRoom()
            return true
            
        case "users", "list-users":
            await listUsers(client: client, roomId: roomId)
            return false
            
        case "rooms", "list-rooms":
            await listRooms(client: client)
            return false
            
        case "info", "room-info":
            await showRoomInfo(client: client, roomId: roomId)
            return false
            
        case "history":
            showHistory(context: context)
            return false
            
        default:
            print("❌ Unknown command: /\(cmd)")
            print("💡 Type /help to see available commands")
            return false
        }
    }
    
    private static func showHelp() {
        print("\n📚 Available Commands:")
        print("  /help           - Show this help message")
        print("  /exit           - Leave current room and join another")
        print("  /bye            - Exit application (works globally)")
        print("  /users          - List users in current room")
        print("  /rooms          - List all available rooms")
        print("  /info           - Show current room information")
        print("  /history        - Show recent message history")
        print("")
    }
    
    private static func listUsers(client: ChatAPIClient, roomId: String) async {
        do {
            let users = try await client.getRoomUsers(roomId: roomId)
            print("\n👥 Users in room (\(users.count)):")
            for user in users {
                print("  • \(user.username)")
            }
            print("")
        } catch {
            print("❌ Failed to fetch users: \(error.localizedDescription)")
        }
    }
    
    private static func listRooms(client: ChatAPIClient) async {
        do {
            let rooms = try await client.listRooms()
            print("\n💬 Available rooms (\(rooms.count)):")
            for room in rooms {
                let lock = room.hasPassword ? "🔒" : "🔓"
                print("  \(lock) [\(room.userCount) users] \(room.name)")
                print("     ID: \(room.id)")
            }
            print("")
        } catch {
            print("❌ Failed to fetch rooms: \(error.localizedDescription)")
        }
    }
    
    private static func showRoomInfo(client: ChatAPIClient, roomId: String) async {
        do {
            let room = try await client.getRoomInfo(roomId: roomId)
            print("\n📋 Room Information:")
            print("  Name: \(room.name)")
            print("  ID: \(room.id)")
            print("  Users: \(room.userCount)")
            print("  Password: \(room.hasPassword ? "Yes" : "No")")
            print("  Created: \(room.createdAt)")
            print("")
        } catch {
            print("❌ Failed to fetch room info: \(error.localizedDescription)")
        }
    }
    
    private static func showHistory(context: ChatContext?) {
        guard let context = context else { return }
        
        let messages = context.messageHistory
        
        if messages.isEmpty {
            print("\n📭 No message history yet\n")
            return
        }
        
        print("\n📜 Recent Messages (\(messages.count)):")
        for message in messages {
            let timestamp = formatTime(message.timestamp)
            switch message.type {
            case .message:
                print("[\(timestamp)] \(message.username): \(message.content)")
            case .userJoined:
                print("[\(timestamp)] → \(message.content)")
            case .userLeft:
                print("[\(timestamp)] ← \(message.content)")
            case .system:
                print("[\(timestamp)] [SYSTEM] \(message.content)")
            }
        }
        print("")
    }
    
    private static func sendMessage(_ content: String, ws: WebSocket) {
        let message = SendMessageRequest(content: content)
        if let data = try? JSONEncoder().encode(message),
           let json = String(data: data, encoding: .utf8) {
            ws.send(json)
        }
    }
    
    private static func handleClose(client: ChatAPIClient, roomId: String, userId: String) {
        print("\n\n🔌 Disconnected from server")
        
        Task {
            do {
                try await client.leaveRoom(roomId: roomId, userId: userId)
            } catch {
                // Ignore errors on cleanup
            }
        }
        
        Foundation.exit(0)
    }
    
    static func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "??:??"
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        return timeFormatter.string(from: date)
    }
}