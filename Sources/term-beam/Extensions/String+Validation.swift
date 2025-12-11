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
}
