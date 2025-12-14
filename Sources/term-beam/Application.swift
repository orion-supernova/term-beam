import Foundation
import ArgumentParser

// MARK: - Global Cleanup Handler
// Note: Signal handlers cannot capture context, so we use a global actor-isolated variable
actor GlobalCleanupHandler {
    static let shared = GlobalCleanupHandler()

    private var coordinator: ChatCoordinator?

    func setCoordinator(_ coordinator: ChatCoordinator) {
        self.coordinator = coordinator
    }

    func cleanup() async {
        await coordinator?.cleanup()
    }

    func clearCoordinator() {
        self.coordinator = nil
    }
}

private func setupGlobalSignalHandler() {
    signal(SIGINT) { _ in
        print("\n\n🛑 Shutting down...")
        Task {
            await GlobalCleanupHandler.shared.cleanup()
            Foundation.exit(0)
        }
    }
}

// MARK: - Main Application Entry Point

@main
struct TermBeamApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "term-beam",
        abstract: "Terminal chat client - beam messages across the network",
        version: "1.0.0"
    )

    @Option(name: .shortAndLong, help: "Server URL")
    var server: String?

    func run() async throws {
        let config = AppConfiguration.default

        // Setup dependencies
        let input = ConsoleInputReader()
        let output = ConsoleOutputWriter()
        await output.setInputReader(input)
        let presenter = UIPresenter(output: output)

        // Show welcome
        await presenter.showWelcome()

        // Get server URL
        let serverURL = try await getServerURL(
            input: input,
            presenter: presenter,
            config: config
        )

        // Wait for server and get final URL
        let finalServerURL = try await connectToServer(
            initialURL: serverURL,
            input: input,
            presenter: presenter,
            config: config
        )

        await presenter.showServerOnline()

        // Create API client with final URL
        let apiClient = HTTPChatAPIClient(baseURL: finalServerURL)

        // Setup services
        let roomService = RoomService(
            apiClient: apiClient,
            presenter: presenter,
            input: input
        )

        let connectionService = ConnectionService(
            apiClient: apiClient,
            presenter: presenter
        )

        // Setup coordinator
        // Note: Username will be asked per room in the coordinator
        let coordinator = ChatCoordinator(
            serverURL: finalServerURL,
            apiClient: apiClient,
            roomService: roomService,
            connectionService: connectionService,
            presenter: presenter,
            input: input,
            config: config
        )

        // Setup signal handling for graceful shutdown
        await GlobalCleanupHandler.shared.setCoordinator(coordinator)
        setupGlobalSignalHandler()

        // Start the application (username will be asked inside)
        try await coordinator.start()

        // Cleanup on normal exit
        await GlobalCleanupHandler.shared.clearCoordinator()
    }

    // MARK: - Private Helpers

    private func getServerURL(
        input: any InputReaderProtocol,
        presenter: UIPresenter,
        config: AppConfiguration
    ) async throws -> String {
        if let server = self.server {
            return server.normalizedURL()
        }

        await presenter.showServerPrompt()
        let userInput = await input.readLine(prompt: "Server [\(config.defaultServerURL)]: ")

        if userInput.isEmpty {
            await presenter.showInfo("Using default: \(config.defaultServerURL)")
            return config.defaultServerURL
        } else {
            return userInput.normalizedURL()
        }
    }

    private func connectToServer(
        initialURL: String,
        input: any InputReaderProtocol,
        presenter: UIPresenter,
        config: AppConfiguration
    ) async throws -> String {
        var currentURL = initialURL
        await presenter.showConnecting(to: currentURL)

        while true {
            // Create a temporary client to test connection
            let apiClient = HTTPChatAPIClient(baseURL: currentURL)
            let connectionService = ConnectionService(apiClient: apiClient, presenter: presenter)

            do {
                try await connectionService.waitForServer(
                    serverURL: currentURL,
                    maxQuickAttempts: config.maxConnectionRetries
                )
                return currentURL // Successfully connected
            } catch {
                // Max attempts exceeded, ask user what to do
                await presenter.showRetryOptions()
                let choice = await input.readLine(prompt: "Your choice [r/c/q]: ")

                switch choice.lowercased() {
                case "r", "":
                    await presenter.showInfo("Retrying connection...")
                    try await Task.sleep(for: .seconds(1))
                    continue

                case "c":
                    let newURL = await input.readLine(prompt: "Enter new server URL: ")
                    if !newURL.isEmpty {
                        currentURL = newURL.normalizedURL()
                        await presenter.showConnecting(to: currentURL)
                        continue
                    }

                case "q":
                    await presenter.showGoodbye()
                    throw ExitCode.failure

                default:
                    await presenter.showError("Invalid choice. Please enter 'r', 'c', or 'q'")
                    try await Task.sleep(for: .seconds(1))
                }
            }
        }
    }
}
