import Foundation
import WebSocketKit
import NIOCore
import NIOPosix

// MARK: - WebSocket Client Implementation

actor WebSocketClient: WebSocketClientProtocol {
    private let serverURL: String
    private let eventLoopGroup: EventLoopGroup
    private var webSocket: WebSocket?
    private var _isConnected: Bool = false

    var isConnected: Bool {
        get async { _isConnected }
    }

    init(serverURL: String, eventLoopGroup: EventLoopGroup? = nil) {
        self.serverURL = serverURL
        self.eventLoopGroup = eventLoopGroup ?? MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect(
        roomId: String,
        userId: String,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) async throws {
        let wsURL = convertToWebSocketURL(serverURL)
        let fullURL = "\(wsURL)/ws/\(roomId)/\(userId)"

        do {
            try await WebSocket.connect(to: fullURL, on: eventLoopGroup) { ws in
                self.handleConnection(
                    ws: ws,
                    onMessage: onMessage,
                    onDisconnect: onDisconnect
                )
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
        _isConnected = false
        try? await webSocket?.close(code: .normalClosure)
        webSocket = nil
    }

    // MARK: - Private Helpers

    private func handleConnection(
        ws: WebSocket,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) {
        Task {
            await setWebSocket(ws)
        }

        ws.onText { _, text in
            Self.parseAndHandleMessage(text: text, onMessage: onMessage)
        }

        ws.onClose.whenComplete { _ in
            Task {
                await self.handleDisconnection()
                onDisconnect()
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
