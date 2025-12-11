import Foundation

// MARK: - Console Input Reader

actor ConsoleInputReader: InputReaderProtocol {
    func readLine(prompt: String) async -> String {
        // Use Task.detached to avoid actor isolation issues with synchronous I/O
        await Task.detached {
            print(prompt, terminator: "")
            fflush(stdout)

            // Read directly from stdin synchronously
            guard let line = Swift.readLine() else {
                return ""
            }
            return line
        }.value
    }

    func readSecureLine(prompt: String) async -> String {
        await Task.detached {
            print(prompt, terminator: "")
            fflush(stdout)

            var buf = [Int8](repeating: 0, count: 8192)
            guard let ptr = readpassphrase("", &buf, buf.count, 0) else {
                return ""
            }
            return String(cString: ptr)
        }.value
    }
}
