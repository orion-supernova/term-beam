# Build and Run Guide

## Quick Start

### 1. Build the project
```bash
swift build
```

### 2. Run the client
```bash
swift run ChatClient
```

Or with options:
```bash
swift run term-beam --server localhost:8080
```

### 3. Install globally (optional)
```bash
make install
```

Then run from anywhere:
```bash
chat-client
```

## Build Options

### Debug Build (default)
```bash
swift build
```
- Includes debug symbols
- Faster compilation
- Larger binary

### Release Build
```bash
swift build -c release
```
- Optimized for performance
- Smaller binary
- Recommended for production

## Running Options

### Interactive Mode (Recommended)
```bash
swift run term-beam
```
You'll be prompted for:
1. Server URL (default: shell-star-production.up.railway.app)
2. Room selection (create or join)
3. Room details (ID/name and password)
4. Username for the selected room

### With Command-Line Arguments
```bash
# Specify custom server
swift run term-beam --server chat.example.com

# Connect to localhost
swift run term-beam -s localhost:8080
```

**Note**: Username is now requested during the interactive flow for better room-specific context.

## Troubleshooting

### Build Errors

**Error: Package resolution failed**
```bash
# Clean and rebuild
swift package clean
swift package resolve
swift build
```

**Error: Cannot find 'WebSocketKit'**
```bash
# Update dependencies
swift package update
swift build
```

### Runtime Errors

**Error: Cannot connect to server**
- Ensure the server is running
- Check the server URL and port
- Verify firewall settings

**Error: WebSocket connection failed**
- Verify the server supports WebSockets
- Check if HTTPS/WSS is required
- Ensure room ID is valid

**Error: Authentication failed**
- Check room password
- Verify username isn't already taken

## Development

### Clean Build
```bash
make clean
# or
swift package clean
```

### Run Tests (when implemented)
```bash
swift test
```

### Build for Distribution
```bash
swift build -c release
# Binary at: .build/release/ChatClient
```

### Install to Custom Location
```bash
swift build -c release
cp .build/release/ChatClient /your/custom/path/
```

## System Requirements

- macOS 13.0 or later
- Swift 6.0 or later
- Xcode 15.0 or later (for development)

## Files Generated

### Build Artifacts
- `.build/` - Build output (ignored by git)
  - `debug/` - Debug builds
  - `release/` - Release builds
  - `checkouts/` - Downloaded dependencies

### Package Files
- `.swiftpm/` - Swift Package Manager metadata
- `Package.resolved` - Locked dependency versions

## Environment Variables

Currently, the application does not use environment variables. All configuration is done via:
- Command-line arguments
- Interactive prompts
- `AppConfiguration` in code

## Performance

### Memory Usage
- Typical: ~20-30 MB
- WebSocket active: ~30-40 MB
- Message history capped at 100 messages

### CPU Usage
- Idle: <1%
- Active messaging: 1-5%
- Spikes during connection/reconnection

## Known Limitations

1. **No persistent message history** - Messages cleared on exit
2. **Single room at a time** - Cannot join multiple rooms
3. **No file uploads** - Text messages only
4. **No rich formatting** - Plain text only
5. **No offline mode** - Requires active connection

## Next Steps

After successful build and run:
1. Connect to your chat server
2. Create or join a room
3. Start chatting!
4. Use `/help` to see available commands

## Documentation

- `README.md` - User guide and features
- `ARCHITECTURE.md` - Technical architecture
- `REFACTORING_SUMMARY.md` - Refactoring details
- `COMPONENT_DIAGRAM.md` - Visual architecture

## Getting Help

If you encounter issues:
1. Check this guide
2. Review error messages
3. Check server logs
4. Verify network connectivity
5. Try with default server (shell-star-production.up.railway.app) or localhost

## Example Session

```bash
$ swift run term-beam
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

Enjoy using ChatClient!
