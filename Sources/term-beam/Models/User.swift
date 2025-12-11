import Foundation

// MARK: - User Models

struct UserResponse: Codable, Sendable, Equatable {
    let id: String
    let username: String
    let joinedAt: String
}
