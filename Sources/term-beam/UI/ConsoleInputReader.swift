import Foundation

// MARK: - Console Input Reader

actor ConsoleInputReader: InputReaderProtocol {
    private var currentPrompt: String = ""

    func readLine(prompt: String) async -> String {
        await setCurrentPrompt(prompt)

        // Use Task.detached to avoid actor isolation issues with synchronous I/O
        let result = await Task.detached {
            print(prompt, terminator: "")

            // Read directly from stdin synchronously
            guard let line = Swift.readLine() else {
                return ""
            }
            return line
        }.value

        await clearCurrentPrompt()
        return result
    }

    nonisolated func getCurrentPrompt() async -> String {
        await getPrompt()
    }

    nonisolated func clearLine() async {
        await performClearLine()
    }

    nonisolated func redrawPrompt() async {
        await performRedrawPrompt()
    }

    private func getPrompt() -> String {
        currentPrompt
    }

    private func performClearLine() {
        // Clear current line: move cursor to beginning, clear to end of line
        print("\r\u{001B}[K", terminator: "")
    }

    private func performRedrawPrompt() {
        if !currentPrompt.isEmpty {
            print(currentPrompt, terminator: "")
        }
    }

    private func setCurrentPrompt(_ prompt: String) {
        currentPrompt = prompt
    }

    private func clearCurrentPrompt() {
        currentPrompt = ""
    }

    func readSecureLine(prompt: String) async -> String {
        return await Task.detached {
            print(prompt, terminator: "")

            #if os(Linux)
            // On Linux, use getpass or fallback to regular input
            guard let line = Swift.readLine() else {
                return ""
            }
            return line
            #else
            var buf = [Int8](repeating: 0, count: 8192)
            guard let ptr = readpassphrase("", &buf, buf.count, 0) else {
                return ""
            }
            return String(cString: ptr)
            #endif
        }.value
    }
}
