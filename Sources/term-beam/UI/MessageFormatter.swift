import Foundation

// MARK: - Message Formatter

struct MessageFormatter: Sendable {
    static func formatMessage(_ message: Message, currentUsername: String) -> String {
        let timestamp = formatTime(message.timestamp)

        switch message.type {
        case .message:
            if message.username == currentUsername {
                return "[\(timestamp)] 💚 You: \(message.content)"
            } else {
                return "[\(timestamp)] 💙 \(message.username): \(message.content)"
            }
        case .userJoined:
            return "[\(timestamp)] → \(message.content)"
        case .userLeft:
            return "[\(timestamp)] ← \(message.content)"
        case .system:
            return "[\(timestamp)] 🔔 [SYSTEM] \(message.content)"
        }
    }

    static func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "??:??"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        return timeFormatter.string(from: date)
    }
}
