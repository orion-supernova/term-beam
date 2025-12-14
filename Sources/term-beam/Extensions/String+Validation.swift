import Foundation

// MARK: - String Extensions

extension String {
    /// Normalizes a URL string by adding protocol if missing
    func normalizedURL() -> String {
        var url = self.trimmingCharacters(in: .whitespaces)

        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }

        return url
    }

    /// Checks if the string represents a localhost address
    var isLocalhost: Bool {
        contains("localhost") || contains("127.0.0.1")
    }

    /// Validates and sanitizes username input
    var isValidUsername: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count >= 2, trimmed.count <= 50 else {
            return false
        }
        // Allow alphanumeric, spaces, dashes, underscores
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        return trimmed.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }

    /// Validates room name
    var isValidRoomName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count >= 2, trimmed.count <= 100 else {
            return false
        }
        return true
    }

    /// Sanitize message content
    func sanitized() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
