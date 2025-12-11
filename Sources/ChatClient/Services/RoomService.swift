import Foundation

// MARK: - Room Service
/// Handles room operations (create, join, leave, list)
/// Single Responsibility: Room management

actor RoomService {
    private let apiClient: ChatAPIClientProtocol
    private let presenter: UIPresenter
    private let input: InputReaderProtocol

    init(apiClient: ChatAPIClientProtocol, presenter: UIPresenter, input: InputReaderProtocol) {
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

    func createAndJoinRoom(username: String) async throws -> (roomId: String, response: JoinRoomResponse) {
        let name = await input.readLine(prompt: "Enter room name: ")
        guard !name.isEmpty else {
            await presenter.showError("Room name cannot be empty")
            throw ChatError.invalidInput("Room name cannot be empty")
        }

        let password = await input.readSecureLine(prompt: "Enter password (leave empty for no password): ")
        let finalPassword = password.isEmpty ? nil : password

        await presenter.showInfo("Creating room...")
        let room = try await createRoom(name: name, password: finalPassword)
        await presenter.showSuccess("Room created: \(room.name)")

        let joinResponse = try await joinRoom(roomId: room.id, username: username, password: finalPassword)
        return (room.id, joinResponse)
    }

    func joinExistingRoom(username: String) async throws -> (roomId: String, response: JoinRoomResponse) {
        let roomId = await input.readLine(prompt: "Enter room ID: ")
        guard !roomId.isEmpty else {
            await presenter.showError("Room ID cannot be empty")
            throw ChatError.invalidInput("Room ID cannot be empty")
        }

        let password = await input.readSecureLine(prompt: "Enter room password (if any): ")
        let finalPassword = password.isEmpty ? nil : password

        await presenter.showInfo("Joining room...")
        let joinResponse = try await joinRoom(roomId: roomId, username: username, password: finalPassword)
        return (roomId, joinResponse)
    }
}
