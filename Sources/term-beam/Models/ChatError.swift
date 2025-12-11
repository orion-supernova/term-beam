import Foundation

// MARK: - Error Types

enum ChatError: Error, LocalizedError, Equatable {
    case serverError(String)
    case networkError(String)
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case connectionFailed
    case webSocketError(String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let msg):
            return "Server error: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .authenticationFailed:
            return "Authentication failed"
        case .connectionFailed:
            return "Connection failed"
        case .webSocketError(let msg):
            return "WebSocket error: \(msg)"
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        }
    }
}

struct ErrorResponse: Codable, Sendable {
    let error: Bool
    let reason: String
}
