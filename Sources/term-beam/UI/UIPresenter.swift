import Foundation

// MARK: - UI Presenter
/// Responsible for displaying UI elements
/// Follows Single Responsibility Principle

actor UIPresenter {
    private let output: OutputWriterProtocol

    init(output: OutputWriterProtocol) {
        self.output = output
    }

    func showWelcome() async {
        await output.writeLine("╔════════════════════════════════════════╗")
        await output.writeLine("║          term-beam v1.0               ║")
        await output.writeLine("║   Beam messages across the network    ║")
        await output.writeLine("╚════════════════════════════════════════╝")
        await output.writeLine("")
    }

    func showServerPrompt() async {
        await output.writeLine("Enter the chat server address (or press Enter for default):")
        await output.writeLine("  Examples:")
        await output.writeLine("    • shell-star-production.up.railway.app (press Enter)")
        await output.writeLine("    • localhost:8080")
        await output.writeLine("    • 192.168.1.100:8080")
        await output.writeLine("    • chat.example.com")
        await output.writeLine("")
    }

    func showConnecting(to url: String) async {
        await output.writeLine("\n🌐 Connecting to: \(url)")
    }

    func showCheckingConnection() async {
        await output.writeLine("🔍 Checking server connection...")
    }

    func showServerOnline() async {
        await output.writeLine("✅ Server is online\n")
    }

    func showConnectionError(url: String, isLocalhost: Bool) async {
        await output.writeLine("⚠️  Cannot connect to server at \(url)")
        await output.writeLine("")

        if isLocalhost {
            await output.writeLine("💡 The server is not running. You can:")
            await output.writeLine("   1. Start the server in another terminal")
            await output.writeLine("   2. Try a different server address")
            await output.writeLine("   3. Wait for the server to start (will retry automatically)")
            await output.writeLine("")
        }
    }

    func showRetrying(attempt: Int, maxAttempts: Int) async {
        await output.writeLine("🔄 Retrying... (attempt \(attempt)/\(maxAttempts))")
    }

    func showRetryOptions() async {
        await output.writeLine("")
        await output.writeLine("Choose an option:")
        await output.writeLine("  [r] Retry connection")
        await output.writeLine("  [c] Change server address")
        await output.writeLine("  [q] Quit")
        await output.writeLine("")
    }

    func showWelcomeUser(username: String) async {
        await output.writeLine("\n💬 Welcome, @\(username)!")
        await output.writeLine("Type /help to see available commands\n")
    }

    func showRooms(_ rooms: [RoomResponse]) async {
        if rooms.isEmpty {
            await output.writeLine("📭 No rooms available.\n")
            return
        }

        await output.writeLine("\n💬 Available rooms:")
        for room in rooms {
            let lock = room.hasPassword ? "🔒" : "🔓"
            await output.writeLine("  \(lock) [\(room.userCount) users] \(room.name)")
            await output.writeLine("     ID: \(room.id)")
        }
        await output.writeLine("")
    }

    func showJoinedRoom(room: JoinRoomResponse, currentUsername: String) async {
        await output.writeLine("✅ Joined '\(room.room.name)'")

        if room.users.count > 1 {
            await output.writeLine("👥 Users already in room:")
            for user in room.users where user.username != currentUsername {
                let timestamp = MessageFormatter.formatTime(user.joinedAt)
                await output.writeLine("  [\(timestamp)] → \(user.username) is here")
            }
        } else {
            await output.writeLine("👤 You are the first one here!")
        }

        await output.writeLine("\n💬 Loading chat interface...")
        await output.writeLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        await output.writeLine("Room: \(room.room.name) | User: @\(currentUsername)")
        await output.writeLine("Type /help for commands | Type /bye to exit app")
        await output.writeLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    func showMessage(_ message: Message, currentUsername: String) async {
        let formatted = MessageFormatter.formatMessage(message, currentUsername: currentUsername)
        await output.writeLine(formatted)
    }

    func showError(_ message: String) async {
        await output.writeLine("❌ \(message)")
    }

    func showInfo(_ message: String) async {
        await output.writeLine("ℹ️  \(message)")
    }

    func showSuccess(_ message: String) async {
        await output.writeLine("✅ \(message)")
    }

    func showHelp() async {
        await output.writeLine("\n📚 Available Commands:")
        await output.writeLine("")
        await output.writeLine("  Global Commands (work anywhere):")
        await output.writeLine("    /help         - Show this help message")
        await output.writeLine("    /bye          - Exit application")
        await output.writeLine("    /quit         - Exit application (alias)")
        await output.writeLine("")
        await output.writeLine("  In-Room Commands:")
        await output.writeLine("    /exit         - Leave current room and join another")
        await output.writeLine("    /leave        - Leave current room (alias)")
        await output.writeLine("    /users        - List users in current room")
        await output.writeLine("    /rooms        - List all available rooms")
        await output.writeLine("    /info         - Show current room information")
        await output.writeLine("    /history      - Show recent message history")
        await output.writeLine("")
    }

    func showUsers(_ users: [UserResponse]) async {
        await output.writeLine("\n👥 Users in room (\(users.count)):")
        for user in users {
            await output.writeLine("  • \(user.username)")
        }
        await output.writeLine("")
    }

    func showRoomInfo(_ room: RoomResponse) async {
        await output.writeLine("\n📋 Room Information:")
        await output.writeLine("  Name: \(room.name)")
        await output.writeLine("  ID: \(room.id)")
        await output.writeLine("  Users: \(room.userCount)")
        await output.writeLine("  Password: \(room.hasPassword ? "Yes" : "No")")
        await output.writeLine("  Created: \(room.createdAt)")
        await output.writeLine("")
    }

    func showHistory(_ messages: [Message], currentUsername: String) async {
        if messages.isEmpty {
            await output.writeLine("\n📭 No message history yet\n")
            return
        }

        await output.writeLine("\n📜 Recent Messages (\(messages.count)):")
        for message in messages {
            let formatted = MessageFormatter.formatMessage(message, currentUsername: currentUsername)
            await output.writeLine(formatted)
        }
        await output.writeLine("")
    }

    func showDisconnected() async {
        await output.writeLine("\n\n🔌 Disconnected from server")
    }

    func showGoodbye() async {
        await output.writeLine("\n👋 Goodbye!")
    }
}
