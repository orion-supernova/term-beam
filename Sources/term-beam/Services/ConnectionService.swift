import Foundation

// MARK: - Connection Service
/// Handles server connection and health checks
/// Single Responsibility: Connection management

actor ConnectionService {
    let apiClient: any ChatAPIClientProtocol
    private let presenter: UIPresenter

    init(apiClient: any ChatAPIClientProtocol, presenter: UIPresenter) {
        self.apiClient = apiClient
        self.presenter = presenter
    }

    func checkHealth() async -> Bool {
        await apiClient.checkHealth()
    }

    func waitForServer(serverURL: String, maxQuickAttempts: Int = 3) async throws {
        await presenter.showCheckingConnection()

        var attempts = 0

        while true {
            let isHealthy = await apiClient.checkHealth()

            if isHealthy {
                return
            }

            attempts += 1

            if attempts == 1 {
                let isLocalhost = serverURL.contains("localhost") || serverURL.contains("127.0.0.1")
                await presenter.showConnectionError(url: serverURL, isLocalhost: isLocalhost)
            }

            if attempts <= maxQuickAttempts {
                await presenter.showRetrying(attempt: attempts, maxAttempts: maxQuickAttempts)
                try await Task.sleep(for: .seconds(2))
            } else {
                // Exceeded max attempts - caller should handle retry logic
                throw ChatError.connectionFailed
            }
        }
    }
}
