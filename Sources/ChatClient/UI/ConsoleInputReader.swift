import Foundation

// MARK: - Console Input Reader

actor ConsoleInputReader: InputReaderProtocol {
    func readLine(prompt: String) async -> String {
        await withCheckedContinuation { continuation in
            print(prompt, terminator: "")
            fflush(stdout)
            let input = Swift.readLine() ?? ""
            continuation.resume(returning: input)
        }
    }

    func readSecureLine(prompt: String) async -> String {
        await withCheckedContinuation { continuation in
            print(prompt, terminator: "")
            fflush(stdout)

            var buf = [Int8](repeating: 0, count: 8192)
            guard let ptr = readpassphrase("", &buf, buf.count, 0) else {
                continuation.resume(returning: "")
                return
            }
            let password = String(cString: ptr)
            continuation.resume(returning: password)
        }
    }
}
