import Foundation
import WebSocketKit
import ArgumentParser
import NIOCore
import NIOPosix

@main
struct ChatClient: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat-client",
        abstract: "Terminal chat client for Vapor chat server"
    )
    
    @Option(name: .shortAndLong, help: "Server URL (default: http://localhost:8080)")
    var server: String = "http://localhost:8080"
    
    @Option(name: .shortAndLong, help: "Your username")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Room ID to join (optional)")
    var room: String?
    
    func run() async throws {
        print("╔════════════════════════════════════════╗")
        print("║   Terminal Chat Client (Swift)        ║")
        print("╚════════════════════════════════════════╝")
        print("")
        print("🌐 Server: \(server)")
        print("")
        
        let client = ChatAPIClient(baseURL: server)
        
        // Check server health
        print("🔍 Checking server connection...")
        guard await client.checkHealth() else {
            print("❌ Cannot connect to server at \(server)")
            print("💡 Please start the server or check the URL")
            throw ExitCode.failure
        }
        print("✅ Server is online\n")
        
        // Get username
        let username = self.username ?? readLine(prompt: "Enter your username: ")
        guard !username.isEmpty else {
            print("❌ Username cannot be empty")
            throw ExitCode.failure
        }
        
        // List available rooms
        print("\n📋 Fetching available rooms...")
        let rooms = try await client.listRooms()
        
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
        
        // Create or join room
        let choice = readLine(prompt: "Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: ")
        
        let roomId: String
        let roomName: String
        let password: String?
        
        if choice.lowercased().hasPrefix("c") {
            // Create room
            let name = readLine(prompt: "Enter room name: ")
            guard !name.isEmpty else {
                print("❌ Room name cannot be empty")
                throw ExitCode.failure
            }
            
            let pwd = readLine(prompt: "Enter password (leave empty for no password): ", secure: true)
            password = pwd.isEmpty ? nil : pwd
            
            print("\n🔨 Creating room...")
            let room = try await client.createRoom(name: name, password: password)
            roomId = room.id
            roomName = room.name
            print("✅ Room created: \(roomName)")
        } else {
            // Join existing room
            roomId = self.room ?? readLine(prompt: "Enter room ID: ")
            guard !roomId.isEmpty else {
                print("❌ Room ID cannot be empty")
                throw ExitCode.failure
            }
            
            let pwd = readLine(prompt: "Enter room password (if any): ", secure: true)
            password = pwd.isEmpty ? nil : pwd
            roomName = "Unknown" // Will be updated after joining
        }
        
        // Join the room
        print("\n🚪 Joining room...")
        let joinResponse = try await client.joinRoom(roomId: roomId, username: username, password: password)
        let userId = joinResponse.userId
        let actualRoomName = joinResponse.room.name
        
        print("✅ Joined '\(actualRoomName)'")
        print("👥 Users in room:")
        for user in joinResponse.users {
            let emoji = user.username == username ? "👤" : "👥"
            print("   \(emoji) \(user.username)")
        }
        
        print("\n💬 Loading chat interface...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Room: \(actualRoomName) | User: @\(username)")
        print("Type your messages and press Enter to send")
        print("Press Ctrl+C to exit")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        // Setup cleanup handler
        signal(SIGINT) { _ in
            print("\n\n👋 Goodbye!")
            Foundation.exit(0)
        }
        
        // Start chat session
        let chatSession = ChatSession(
            client: client,
            roomId: roomId,
            userId: userId,
            username: username,
            roomName: actualRoomName,
            serverURL: server
        )
        
        try await chatSession.start()
    }
    
    func readLine(prompt: String, secure: Bool = false) -> String {
        print(prompt, terminator: "")
        fflush(stdout)
        
        if secure {
            // Hide input for passwords
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
    let client: ChatAPIClient
    let roomId: String
    let userId: String
    let username: String
    let roomName: String
    let serverURL: String
    
    private var ws: WebSocket?
    private var isConnected = false
    
    init(client: ChatAPIClient, roomId: String, userId: String, username: String, roomName: String, serverURL: String) {
        self.client = client
        self.roomId = roomId
        self.userId = userId
        self.username = username
        self.roomName = roomName
        self.serverURL = serverURL
    }
    
    func start() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Extract host and port from serverURL
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
                
                // Handle incoming messages
                ws.onText { _, text in
                    Self.handleMessage(text, username: username)
                }
                
                ws.onClose.whenComplete { _ in
                    Task {
                        Self.handleClose(client: client, roomId: roomId, userId: userId)
                    }
                }
                
                // Handle user input in background
                Task {
                    Self.handleUserInput(ws: ws)
                }
            }.get()
            
            // Keep the event loop running
            try await Task.sleep(for: .seconds(999999))
        } catch {
            print("❌ Failed to connect to WebSocket: \(error)")
            throw error
        }
    }
    
    private static func handleMessage(_ text: String, username: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        
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
    
    private static func handleUserInput(ws: WebSocket) {
        while true {
            if let line = readLine(), !line.isEmpty {
                Self.sendMessage(line, ws: ws)
            }
        }
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
        
        // Try to leave room gracefully
        Task {
            do {
                try await client.leaveRoom(roomId: roomId, userId: userId)
            } catch {
                // Ignore errors on cleanup
            }
        }
        
        Foundation.exit(0)
    }
    
    private static func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "??:??"
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        return timeFormatter.string(from: date)
    }
}