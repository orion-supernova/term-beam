import Foundation

// MARK: - Console Output Writer

actor ConsoleOutputWriter: OutputWriterProtocol {
    private weak var inputReader: ConsoleInputReader?

    func setInputReader(_ reader: ConsoleInputReader) {
        self.inputReader = reader
    }

    func write(_ text: String) async {
        print(text, terminator: "")
        fflush(stdout)
    }

    func writeLine(_ text: String) async {
        // Clear current input line if user is typing
        if let reader = inputReader {
            let currentPrompt = await reader.getCurrentPrompt()
            if !currentPrompt.isEmpty {
                await reader.clearLine()
            }
        }

        print(text)

        // Redraw the prompt after the message
        if let reader = inputReader {
            await reader.redrawPrompt()
        }
    }
}
