import Foundation

// MARK: - Global Command Handler
/// Handles commands that should work anywhere in the application
/// Single Responsibility: Global command processing

struct GlobalCommandHandler {
    private let presenter: UIPresenter

    init(presenter: UIPresenter) {
        self.presenter = presenter
    }

    /// Check if input is a global command and handle it
    /// Returns: (wasGlobalCommand, shouldExit)
    func handleIfGlobal(_ input: String) async -> (wasGlobalCommand: Bool, shouldExit: Bool) {
        guard input.hasPrefix("/") else {
            return (false, false)
        }

        let parts = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        let command = parts.first?.lowercased() ?? ""

        switch command {
        case "help":
            await showGlobalHelp()
            return (true, false)

        case "bye", "quit", "exit":
            await presenter.showGoodbye()
            return (true, true)

        default:
            // Not a global command
            return (false, false)
        }
    }

    private func showGlobalHelp() async {
        await presenter.showHelp()
    }
}
