import Foundation

// MARK: - Application Configuration
/// Centralized configuration
/// Follows Open/Closed Principle - easily extensible

struct AppConfiguration: Sendable {
    let defaultServerURL: String
    let maxConnectionRetries: Int
    let connectionRetryDelay: Duration
    let maxMessageHistory: Int

    static let `default` = AppConfiguration(
        defaultServerURL: "http://localhost:8080",
        maxConnectionRetries: 3,
        connectionRetryDelay: .seconds(2),
        maxMessageHistory: 100
    )

    init(
        defaultServerURL: String,
        maxConnectionRetries: Int,
        connectionRetryDelay: Duration,
        maxMessageHistory: Int
    ) {
        self.defaultServerURL = defaultServerURL
        self.maxConnectionRetries = maxConnectionRetries
        self.connectionRetryDelay = connectionRetryDelay
        self.maxMessageHistory = maxMessageHistory
    }
}
