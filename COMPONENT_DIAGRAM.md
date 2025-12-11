# Component Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Application Layer                            │
│                        (Application.swift)                           │
│  - CLI argument parsing                                              │
│  - Dependency setup and injection                                    │
│  - Signal handling                                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Coordination Layer                              │
│                     (ChatCoordinator.swift)                          │
│  - Application flow coordination                                     │
│  - Room selection and joining                                        │
│  - Session lifecycle management                                      │
└─────┬───────────────────────────────────────────────────────────────┘
      │
      ├──────────────────┬──────────────────┬──────────────────┐
      ▼                  ▼                  ▼                  ▼
┌──────────┐      ┌─────────────┐    ┌──────────────┐  ┌────────────┐
│  Room    │      │ Connection  │    │ Chat Session │  │    UI      │
│ Service  │      │  Service    │    │   Service    │  │ Presenter  │
└────┬─────┘      └──────┬──────┘    └──────┬───────┘  └─────┬──────┘
     │                   │                   │                │
     │                   │                   │                │
┌────▼───────────────────▼───────────────────▼────────────────▼──────┐
│                        Service Layer                                │
│                                                                     │
│  RoomService          ConnectionService     ChatSessionService     │
│  - Create room        - Health checks       - WebSocket mgmt       │
│  - Join room          - Retry logic         - Message handling     │
│  - Leave room         - Connection mgmt     - Command processing   │
│  - List rooms/users                         - User input loop      │
│                                                                     │
│  UIPresenter          InputReader           OutputWriter           │
│  - Format & display   - Read user input     - Write to console     │
│  - Show messages      - Secure passwords    - Line buffering       │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
┌────────────────────────┐    ┌──────────────────────┐
│   Networking Layer     │    │    Protocol Layer    │
│                        │    │                      │
│  HTTPChatAPIClient     │◄───┤ ChatAPIClientProtocol│
│  - REST API calls      │    │                      │
│  - Health checks       │    │ WebSocketProtocol    │
│  - Room operations     │    │                      │
│                        │    │ InputReaderProtocol  │
│  WebSocketClient       │    │                      │
│  - Real-time msgs      │◄───┤ OutputWriterProtocol │
│  - Connection mgmt     │    │                      │
└────────────────────────┘    └──────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Model Layer                                 │
│                                                                      │
│  Room Models          Message Models         User Models            │
│  - RoomResponse       - Message              - UserResponse         │
│  - CreateRequest      - MessageType          - JoinResponse         │
│  - JoinRequest        - SendRequest                                 │
│                                                                      │
│  Error Models         Configuration                                 │
│  - ChatError          - AppConfiguration                            │
│  - ErrorResponse      - Default settings                            │
└──────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Application Startup
```
User runs CLI
    │
    ▼
Application.run()
    │
    ├─> Get server URL (from args or prompt)
    ├─> Create dependencies (API client, services, presenter)
    ├─> Connect to server (with retry logic)
    ├─> Get username
    └─> Start ChatCoordinator
```

### 2. Room Selection Flow
```
ChatCoordinator.start()
    │
    ├─> RoomService.listRooms()
    │       │
    │       └─> HTTPChatAPIClient.listRooms()
    │               │
    │               └─> GET /api/rooms
    │
    ├─> UIPresenter.showRooms()
    │
    ├─> InputReader.readLine() [user choice]
    │
    └─> RoomService.createAndJoinRoom() OR joinExistingRoom()
            │
            └─> HTTPChatAPIClient.createRoom() / joinRoom()
                    │
                    └─> POST /api/rooms or /api/rooms/:id/join
```

### 3. Chat Session Flow
```
ChatSessionService.start()
    │
    ├─> WebSocketClient.connect()
    │       │
    │       └─> WebSocket connection to /ws/:roomId/:userId
    │
    ├─> Setup message handler
    │       │
    │       └─> On message received:
    │               ├─> Parse message
    │               ├─> Add to history
    │               └─> UIPresenter.showMessage()
    │
    └─> Start input loop
            │
            └─> While active:
                    ├─> InputReader.readLine()
                    ├─> If command: handleCommand()
                    └─> Else: WebSocketClient.sendMessage()
```

### 4. Command Processing Flow
```
User types "/users"
    │
    ▼
ChatSessionService.handleCommand()
    │
    ├─> Parse command
    │
    ├─> Switch on command type:
    │   ├─> /users    -> RoomService.getRoomUsers()
    │   ├─> /rooms    -> RoomService.listRooms()
    │   ├─> /info     -> RoomService.getRoomInfo()
    │   ├─> /history  -> Show local message history
    │   ├─> /help     -> UIPresenter.showHelp()
    │   └─> /exit     -> Cleanup and return
    │
    └─> UIPresenter.show*() for results
```

## Dependency Graph

```
┌─────────────┐
│ Application │
└──────┬──────┘
       │ creates
       ▼
┌──────────────────┐
│ ChatCoordinator  │
└────┬─────────────┘
     │ depends on
     ├───────────────────┬────────────────┬──────────────┐
     ▼                   ▼                ▼              ▼
┌──────────┐      ┌──────────────┐  ┌─────────┐  ┌──────────┐
│  Room    │      │ Connection   │  │   UI    │  │  Input   │
│ Service  │      │   Service    │  │Presenter│  │  Reader  │
└────┬─────┘      └──────┬───────┘  └─────────┘  └──────────┘
     │                   │
     │ uses              │ uses
     ▼                   ▼
┌──────────────────────────────┐
│   ChatAPIClientProtocol      │ (Interface)
└──────────────┬───────────────┘
               │ implemented by
               ▼
┌──────────────────────────────┐
│    HTTPChatAPIClient         │ (Concrete)
└──────────────────────────────┘
```

## Actor Isolation

```
actor HTTPChatAPIClient
├─ Serializes all API calls
└─ Thread-safe state management

actor WebSocketClient
├─ Serializes WebSocket operations
└─ Thread-safe connection state

actor ConnectionService
├─ Serializes connection checks
└─ Prevents race conditions

actor RoomService
├─ Serializes room operations
└─ Safe concurrent access

actor ChatSessionService
├─ Serializes session state
└─ Safe message history access

actor UIPresenter
├─ Serializes UI updates
└─ Prevents output corruption

actor InputReader
├─ Serializes input reading
└─ Thread-safe input handling
```

## Protocol Abstraction

All services depend on protocols, not concrete implementations:

```
High-level modules          Abstractions              Low-level modules
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RoomService       ────────> ChatAPIClientProtocol <──── HTTPChatAPIClient
                                                   <──── MockAPIClient (tests)

ChatSessionService ───────> WebSocketClientProtocol <─── WebSocketClient
                                                    <─── MockWSClient (tests)

ChatCoordinator   ───────> InputReaderProtocol <──────── ConsoleInputReader
                                                <──────── MockInputReader (tests)

UIPresenter       ───────> OutputWriterProtocol <─────── ConsoleOutputWriter
                                                <─────── MockOutputWriter (tests)
```

## Error Propagation

```
User Action
    │
    ▼
Service Layer
    │ (try await)
    ├─> Success: Continue
    │
    └─> Error thrown
            │
            ▼
        Catch at appropriate level
            │
            ├─> Log error
            ├─> Show user-friendly message
            └─> Decide: retry, abort, or ask user
```

## Lifecycle Management

```
Application Start
    │
    ▼
Create all dependencies
    │
    ├─> Services created with DI
    ├─> Protocols injected
    └─> Configuration passed
            │
            ▼
        Start Coordinator
            │
            ├─> Setup signal handlers
            ├─> Connect to server
            └─> Enter main loop
                    │
                    ├─> Create session
                    ├─> Handle events
                    └─> On exit:
                            │
                            ├─> Cleanup session
                            ├─> Disconnect WebSocket
                            ├─> Leave room
                            └─> Exit gracefully
```

This architecture ensures:
- ✅ Clear separation of concerns
- ✅ Testable components via DI
- ✅ Thread-safe operations via actors
- ✅ Flexible implementations via protocols
- ✅ Proper error handling
- ✅ Clean lifecycle management
