import Foundation

// MARK: - Message Models

struct Message: Codable, Sendable, Equatable {
    let id: String
    let roomId: String
    let userId: String
    let username: String
    let content: String
    let timestamp: String
    let type: MessageType
}

enum MessageType: String, Codable, Sendable {
    case message
    case userJoined
    case userLeft
    case system
}

struct SendMessageRequest: Codable, Sendable {
    let content: String
}
