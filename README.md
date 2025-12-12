# Chat Client

A modern, terminal-based chat client written in Swift for connecting to WebSocket-enabled chat servers. Built with SwiftNIO and WebSocketKit, this client provides a rich command-line interface for real-time messaging.

## Features

- **Real-time Messaging**: WebSocket-based communication for instant message delivery
- **Room Management**: Create password-protected or public chat rooms
- **User Presence**: See who's online and get notifications when users join/leave
- **Message History**: View recent messages with the `/history` command
- **Interactive Commands**: Full suite of commands for room and user management
- **Secure Input**: Password fields hidden during entry
- **Auto-reconnect**: Graceful server connection handling with retry logic
- **Health Checks**: Server availability monitoring before connection
- **Smart Username Handling**: Automatically prompts for a different username if already taken

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later

## Installation

### Option 1: Build and Install

```bash
make install
```

This will build the release version and install it to `/usr/local/bin/chat-client`.

### Option 2: Build Only

```bash
make build
```

The binary will be available at `.build/release/ChatClient`.

### Option 3: Run Directly

```bash
make run
```

Or with Swift directly:

```bash
swift run ChatClient
```

## Usage

### Quick Start

```bash
# Run with default settings (connects to shell-star-production.up.railway.app)
term-beam

# Connect to a specific server or localhost
term-beam --server localhost:8080
term-beam --server your-server.com
```

### Command-Line Options

- `-s, --server`: Server URL (e.g., `localhost:8080`, `chat.example.com`)

**Note**: Username is now requested during the flow for better room-specific context.

### Interactive Mode

When you run the client, you'll be guided through:

1. **Server Connection**: Enter server address or use default `shell-star-production.up.railway.app`
2. **Room Selection**: Choose to create a new room or join an existing one
3. **Room Details**: Enter room ID/name and password (if required)
4. **Username**: Enter your username for the selected room
5. **Chat Interface**: Send messages and use commands

**Note**: Username is requested AFTER room selection to prevent conflicts and provide better context.

## In-Chat Commands

Once connected to a room, you can use these commands:

| Command | Description |
|---------|-------------|
| `/help` | Show all available commands |
| `/exit` or `/leave` | Leave current room and join another |
| `/bye` or `/quit` | Exit the application completely |
| `/users` or `/list-users` | List all users in the current room |
| `/rooms` or `/list-rooms` | List all available rooms on the server |
| `/info` or `/room-info` | Show current room information |
| `/history` | Display recent message history (last 100 messages) |

## Example Session

```
╔════════════════════════════════════════╗
║          term-beam v1.0               ║
║   Beam messages across the network    ║
╚════════════════════════════════════════╝

Enter the chat server address (or press Enter for default):
  Examples:
    • shell-star-production.up.railway.app (press Enter)
    • localhost:8080
    • 192.168.1.100:8080
    • chat.example.com

Server [https://shell-star-production.up.railway.app]:
Using default: https://shell-star-production.up.railway.app

🌐 Connecting to: https://shell-star-production.up.railway.app
🔍 Checking server connection...
✅ Server is online

ℹ️  Fetching available rooms...

💬 Available rooms:
  🔓 [2 users] General Chat
     ID: abc123

Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: j
Enter room ID: abc123
Enter room password (if any):

Enter your username for this room: alice

ℹ️  Joining room as @alice...
✅ Joined 'General Chat'
👥 Users already in room:
  [15:30:21] → bob is here

💬 Loading chat interface...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Room: General Chat | User: @alice
Type /help for commands | Type /bye to exit app
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Hello everyone!
[15:32:15] 💚 You: Hello everyone!
[15:32:18] 💙 bob: Hey alice!
```

## Architecture

### Components

- **ChatClient**: Main entry point using Swift Argument Parser for CLI handling
- **ChatContext**: State management for room and user context
- **ChatAPIClient**: HTTP REST API client (actor-based for thread safety)
- **ChatSession**: WebSocket connection handler and message processor
- **GlobalCleanupHandler**: Signal handling for graceful shutdown

### API Integration

The client expects a server with the following REST endpoints:

- `GET /health` - Health check
- `GET /api/rooms` - List all rooms
- `POST /api/rooms` - Create a new room
- `POST /api/rooms/:id/join` - Join a room
- `DELETE /api/rooms/:id/leave/:userId` - Leave a room
- `GET /api/rooms/:id/users` - Get room users
- `GET /api/rooms/:id` - Get room info

And WebSocket endpoint:

- `WS /ws/:roomId/:userId` - Real-time messaging

### Message Types

- `message`: Regular chat message
- `userJoined`: User join notification
- `userLeft`: User leave notification
- `system`: System announcements

## Dependencies

- [WebSocketKit](https://github.com/vapor/websocket-kit) (2.15.0+): WebSocket client implementation
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) (1.3.0+): Command-line argument parsing

## Development

### Project Structure

```
ChatClient/
├── Package.swift          # Swift package manifest
├── Makefile              # Build automation
├── README.md             # This file
└── Sources/
    └── ChatClient.swift  # Main application source
```

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests (if available)
swift test
```

### Cleaning

```bash
make clean
# or
swift package clean
```

## Server Compatibility

This client is designed to work with WebSocket-enabled chat servers that follow the expected API structure. It's particularly compatible with Vapor-based chat servers but should work with any server implementing the same protocol.

## Troubleshooting

### Cannot Connect to Server

- Ensure the server is running and accessible
- Check that the server URL is correct (including port)
- Verify firewall settings aren't blocking the connection

### WebSocket Connection Failed

- Confirm the server supports WebSocket connections
- Check if the server requires HTTPS/WSS instead of HTTP/WS
- Verify the room ID and user ID are valid

### Password-Protected Rooms

- Enter the password when prompted (input will be hidden)
- Leave password field empty for rooms without passwords

### Username Already Taken

- If a username is already in use in the room, you'll be prompted to enter a different one
- Simply enter a new username and the client will retry automatically
- No need to restart or go back to room selection

## License

This project is available under standard open-source terms.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Author

Built with Swift and SwiftNIO for modern, high-performance terminal-based chat.
