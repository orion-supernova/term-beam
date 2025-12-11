import Foundation

/// Protocol defining the chat API client interface
/// Follows Dependency Inversion Principle (DIP)
protocol ChatAPIClientProtocol: Sendable {
    func checkHealth() async -> Bool
    func listRooms() async throws -> [RoomResponse]
    func createRoom(name: String, password: String?) async throws -> RoomResponse
    func joinRoom(roomId: String, username: String, password: String?) async throws -> JoinRoomResponse
    func leaveRoom(roomId: String, userId: String) async throws
    func getRoomUsers(roomId: String) async throws -> [UserResponse]
    func getRoomInfo(roomId: String) async throws -> RoomResponse
    func getMessageHistory(roomId: String, limit: Int?) async throws -> [Message]
}
