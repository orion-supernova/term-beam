import Foundation

// MARK: - Console Output Writer

actor ConsoleOutputWriter: OutputWriterProtocol {
    func write(_ text: String) async {
        print(text, terminator: "")
        fflush(stdout)
    }

    func writeLine(_ text: String) async {
        print(text)
    }
}
