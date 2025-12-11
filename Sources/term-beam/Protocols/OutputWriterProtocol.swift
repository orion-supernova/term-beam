import Foundation

/// Protocol for writing output
/// Enables testing and different output targets
protocol OutputWriterProtocol: Sendable {
    func write(_ text: String) async
    func writeLine(_ text: String) async
}
