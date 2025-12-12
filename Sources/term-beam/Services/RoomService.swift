import Foundation

// MARK: - Room Service
/// Handles room operations (create, join, leave, list)
/// Single Responsibility: Room management

actor RoomService {
    private let apiClient: any ChatAPIClientProtocol
    private let presenter: UIPresenter
    private let input: any InputReaderProtocol

    init(apiClient: any ChatAPIClientProtocol, presenter: UIPresenter, input: any InputReaderProtocol) {
        self.apiClient = apiClient
        self.presenter = presenter
        self.input = input
    }

    func listRooms() async throws -> [RoomResponse] {
        try await apiClient.listRooms()
    }

    func createRoom(name: String, password: String?) async throws -> RoomResponse {
        try await apiClient.createRoom(name: name, password: password)
    }

    func joinRoom(roomId: String, username: String, password: String?) async throws -> JoinRoomResponse {
        try await apiClient.joinRoom(roomId: roomId, username: username, password: password)
    }

    func leaveRoom(roomId: String, userId: String) async throws {
        try await apiClient.leaveRoom(roomId: roomId, userId: userId)
    }

    func getRoomUsers(roomId: String) async throws -> [UserResponse] {
        try await apiClient.getRoomUsers(roomId: roomId)
    }

    func getRoomInfo(roomId: String) async throws -> RoomResponse {
        try await apiClient.getRoomInfo(roomId: roomId)
    }

    func getMessageHistory(roomId: String, limit: Int?) async throws -> [Message] {
        try await apiClient.getMessageHistory(roomId: roomId, limit: limit)
    }
}
