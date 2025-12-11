import Foundation

/// Protocol for reading user input
/// Enables testing with mock input
protocol InputReaderProtocol: Sendable {
    func readLine(prompt: String) async -> String
    func readSecureLine(prompt: String) async -> String
}
