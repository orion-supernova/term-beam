import Foundation

// MARK: - Console Input Reader

actor ConsoleInputReader: InputReaderProtocol {
    private var currentPrompt: String = ""

    // nonisolated because it performs BLOCKING I/O - must not block the actor
    nonisolated func readLine(prompt: String) async -> String {
        print(prompt, terminator: "")
        return Swift.readLine() ?? ""
    }

    // Actor-isolated - safe to access currentPrompt
    func getCurrentPrompt() async -> String {
        return currentPrompt
    }

    // nonisolated because it's just printing - no actor state needed
    nonisolated func clearLine() async {
        print("\r\u{001B}[K", terminator: "")
    }

    // Actor-isolated - needs to read currentPrompt safely
    func redrawPrompt() async {
        let prompt = currentPrompt
        if !prompt.isEmpty {
            print(prompt, terminator: "")
        }
    }

    // nonisolated because it performs BLOCKING I/O - must not block the actor
    nonisolated func readSecureLine(prompt: String) async -> String {
        #if os(Linux)
        print(prompt, terminator: "")
        return Swift.readLine() ?? ""
        #else
        var buf = [Int8](repeating: 0, count: 8192)

        if let ptr = readpassphrase(prompt, &buf, buf.count, 0) {
            return String(cString: ptr)
        }

        print("\n⚠️  Secure input unavailable, using regular input")
        print(prompt, terminator: "")
        return Swift.readLine() ?? ""
        #endif
    }
}
