import Foundation

enum TerminalSanitizer {
    /// Removes ANSI / CSI escape sequences (e.g. `\u{1B}[?25h` show-cursor from Cursor CLI PTY).
    static func stripEscapeSequences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text
        let esc = "\u{1B}"

        if let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: esc) + "\\[[0-?]*[ -/]*[@-~]"
        ) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Orphan CSI tail when ESC byte was dropped in transit/storage.
        if let bare = try? NSRegularExpression(pattern: "\\[[0-?]*[ -/]*[@-~]$") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = bare.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
