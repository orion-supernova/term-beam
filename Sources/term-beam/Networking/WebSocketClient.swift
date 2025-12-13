import Foundation
import WebSocketKit
import NIOCore
import NIOPosix

// MARK: - WebSocket Client Implementation

actor WebSocketClient: WebSocketClientProtocol {
    private let serverURL: String
    private let eventLoopGroup: any EventLoopGroup
    private var webSocket: WebSocket?
    private var _isConnected: Bool = false

    // Reconnection properties
    private var shouldReconnect: Bool = false
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private var currentRoomId: String?
    private var currentUserId: String?
    private var storedOnMessage: (@Sendable (Message) -> Void)?
    private var storedOnDisconnect: (@Sendable () -> Void)?

    var isConnected: Bool {
        get async { _isConnected }
    }

    init(serverURL: String, eventLoopGroup: (any EventLoopGroup)? = nil) {
        self.serverURL = serverURL
        self.eventLoopGroup = eventLoopGroup ?? MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect(
        roomId: String,
        userId: String,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) async throws {
        // Store connection details for reconnection
        currentRoomId = roomId
        currentUserId = userId
        storedOnMessage = onMessage
        storedOnDisconnect = onDisconnect
        shouldReconnect = true
        reconnectAttempts = 0

        try await attemptConnection(
            roomId: roomId,
            userId: userId,
            onMessage: onMessage,
            onDisconnect: onDisconnect
        )
    }

    private func attemptConnection(
        roomId: String,
        userId: String,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) async throws {
        let wsURL = convertToWebSocketURL(serverURL)
        let fullURL = "\(wsURL)/ws/\(roomId)/\(userId)"

        do {
            try await WebSocket.connect(to: fullURL, on: eventLoopGroup) { ws in
                Task {
                    await self.handleConnection(
                        ws: ws,
                        onMessage: onMessage,
                        onDisconnect: onDisconnect
                    )
                }
            }.get()
        } catch {
            throw ChatError.webSocketError("Failed to connect: \(error.localizedDescription)")
        }
    }

    func sendMessage(_ content: String) async throws {
        guard let ws = webSocket, _isConnected else {
            throw ChatError.webSocketError("Not connected")
        }

        let message = SendMessageRequest(content: content)
        guard let data = try? JSONEncoder().encode(message),
              let json = String(data: data, encoding: .utf8) else {
            throw ChatError.webSocketError("Failed to encode message")
        }

        try await ws.send(json)
    }

    func disconnect() async {
        shouldReconnect = false // Don't reconnect on manual disconnect
        _isConnected = false
        try? await webSocket?.close(code: .normalClosure)
        webSocket = nil
        currentRoomId = nil
        currentUserId = nil
        storedOnMessage = nil
        storedOnDisconnect = nil
    }

    // MARK: - Private Helpers

    private func handleConnection(
        ws: WebSocket,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) async {
        await setWebSocket(ws)

        ws.onText { _, text in
            // Ignore ping messages from server heartbeat
            if text == "ping" {
                return
            }
            Self.parseAndHandleMessage(text: text, onMessage: onMessage)
        }

        ws.onClose.whenComplete { _ in
            Task {
                await self.handleDisconnection()

                // Attempt reconnection if enabled and not at max attempts
                let shouldReconnect = await self.shouldReconnect
                let reconnectAttempts = await self.reconnectAttempts
                let maxAttempts = await self.maxReconnectAttempts

                if shouldReconnect && reconnectAttempts < maxAttempts {
                    await self.attemptReconnection()
                } else {
                    // Give up and notify disconnect
                    onDisconnect()
                }
            }
        }
    }

    private func setWebSocket(_ ws: WebSocket) {
        self.webSocket = ws
        self._isConnected = true
    }

    private func handleDisconnection() {
        self._isConnected = false
        self.webSocket = nil
    }

    private func attemptReconnection() async {
        guard let roomId = currentRoomId,
              let userId = currentUserId,
              let onMessage = storedOnMessage,
              let onDisconnect = storedOnDisconnect else {
            return
        }

        reconnectAttempts += 1
        print("⚠️  Connection lost. Reconnecting... (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

        do {
            try await Task.sleep(for: .seconds(2)) // Wait before reconnecting
            try await attemptConnection(
                roomId: roomId,
                userId: userId,
                onMessage: onMessage,
                onDisconnect: onDisconnect
            )
            // Reset attempts on successful reconnection
            reconnectAttempts = 0
            print("✅ Reconnected successfully!")
        } catch {
            print("❌ Reconnection attempt \(reconnectAttempts) failed: \(error.localizedDescription)")
            // The onClose handler will be called again and retry if attempts remain
        }
    }

    private static func parseAndHandleMessage(
        text: String,
        onMessage: @Sendable (Message) -> Void
    ) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        onMessage(message)
    }

    private func convertToWebSocketURL(_ url: String) -> String {
        if url.starts(with: "https://") {
            return url.replacingOccurrences(of: "https://", with: "wss://")
        } else {
            return url.replacingOccurrences(of: "http://", with: "ws://")
        }
    }

    deinit {
        webSocket?.close(code: .normalClosure)
    }
}
