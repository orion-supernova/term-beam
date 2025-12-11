import Foundation

/// Protocol for WebSocket client operations
/// Enables testing and different implementations
protocol WebSocketClientProtocol: Sendable {
    func connect(
        roomId: String,
        userId: String,
        onMessage: @escaping @Sendable (Message) -> Void,
        onDisconnect: @escaping @Sendable () -> Void
    ) async throws

    func sendMessage(_ content: String) async throws
    func disconnect() async
    var isConnected: Bool { get async }
}
