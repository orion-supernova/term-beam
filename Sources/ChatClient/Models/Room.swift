import Foundation

// MARK: - Room Models

struct RoomResponse: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let hasPassword: Bool
    let userCount: Int
    let createdAt: String
}

struct CreateRoomRequest: Codable, Sendable {
    let name: String
    let password: String?
}

struct JoinRoomRequest: Codable, Sendable {
    let username: String
    let password: String?
}

struct JoinRoomResponse: Codable, Sendable {
    let userId: String
    let room: RoomResponse
    let users: [UserResponse]
}
