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
swift run ChatClient --server localhost:8080 --username alice
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
swift run ChatClient
```
You'll be prompted for:
1. Server URL (default: localhost:8080)
2. Username
3. Room selection (create or join)

### With Command-Line Arguments
```bash
# Specify server
swift run ChatClient --server chat.example.com

# Specify username
swift run ChatClient --username alice

# Both
swift run ChatClient --server localhost:8080 --username bob
```

### Short Options
```bash
swift run ChatClient -s localhost:8080 -u alice
```

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
5. Try with default server (localhost:8080)

## Example Session

```bash
$ swift run ChatClient
╔════════════════════════════════════════╗
║      Terminal Chat Client v1.0        ║
╚════════════════════════════════════════╝

Enter the chat server address (or press Enter for localhost:8080):
  Examples:
    • localhost:8080 or just press Enter
    • 192.168.1.100:8080
    • chat.example.com

Server [localhost:8080]:
Using default: http://localhost:8080

🌐 Connecting to: http://localhost:8080
🔍 Checking server connection...
✅ Server is online

Enter your username: alice

💬 Welcome, @alice!
Type /help to see available commands

📋 Fetching available rooms...

💬 Available rooms:
  🔓 [2 users] General Chat
     ID: abc123

Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: j
Enter room ID: abc123

🚪 Joining room...
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
