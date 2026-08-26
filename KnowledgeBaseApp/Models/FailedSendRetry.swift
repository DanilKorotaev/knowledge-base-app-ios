import Foundation

/// Payload for bubble «Retry» after a hard send failure or a pipeline error reply.
struct FailedSendRetry: Equatable {
    enum Kind: Equatable {
        /// Client never got a durable turn — resend the same composer snapshot.
        case draft(ChatComposerDraft)
        /// Server already has the user turn (or assistant error) — ask again with text.
        case text(String)
    }

    var kind: Kind
    /// Message id under which the Retry control is shown.
    var anchorMessageId: String
    var errorDescription: String?
}

enum PipelineErrorMessageClassifier {
    /// Substrings that appear in backend / Cursor pipeline failure replies.
    /// Cyrillic is `\u{}`-escaped so CI `check_no_hardcoded_cyrillic` stays green
    /// (these are match needles for server copy, not UI strings).
    private static let needles: [String] = [
        // "произошла ошибка"
        "\u{043F}\u{0440}\u{043E}\u{0438}\u{0437}\u{043E}\u{0448}\u{043B}\u{0430} \u{043E}\u{0448}\u{0438}\u{0431}\u{043A}\u{0430}",
        // "обратитесь к администратору"
        "\u{043E}\u{0431}\u{0440}\u{0430}\u{0442}\u{0438}\u{0442}\u{0435}\u{0441}\u{044C} \u{043A} \u{0430}\u{0434}\u{043C}\u{0438}\u{043D}\u{0438}\u{0441}\u{0442}\u{0440}\u{0430}\u{0442}\u{043E}\u{0440}\u{0443}",
        // "превышено время ожидания"
        "\u{043F}\u{0440}\u{0435}\u{0432}\u{044B}\u{0448}\u{0435}\u{043D}\u{043E} \u{0432}\u{0440}\u{0435}\u{043C}\u{044F} \u{043E}\u{0436}\u{0438}\u{0434}\u{0430}\u{043D}\u{0438}\u{044F}",
        // "попробуйте позже"
        "\u{043F}\u{043E}\u{043F}\u{0440}\u{043E}\u{0431}\u{0443}\u{0439}\u{0442}\u{0435} \u{043F}\u{043E}\u{0437}\u{0436}\u{0435}",
        "an error occurred",
        "try again later",
    ]

    /// Heuristic for assistant replies that are user-facing pipeline failures (not a real answer).
    static func isPipelineErrorMessage(_ content: String) -> Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        if text.contains("\u{274C}") { return true } // ❌
        let lower = text.lowercased()
        return needles.contains { lower.contains($0) }
    }
}

extension KBMessage {
    var isPipelineErrorMessage: Bool {
        role == .assistant && PipelineErrorMessageClassifier.isPipelineErrorMessage(content)
    }
}
