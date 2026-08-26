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
    /// Heuristic for assistant replies that are user-facing pipeline failures (not a real answer).
    static func isPipelineErrorMessage(_ content: String) -> Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let lower = text.lowercased()
        if text.contains("❌") { return true }
        if lower.contains("произошла ошибка") { return true }
        if lower.contains("обратитесь к администратору") { return true }
        if lower.contains("превышено время ожидания") { return true }
        if lower.contains("попробуйте позже") { return true }
        if lower.contains("an error occurred") { return true }
        if lower.contains("try again later") { return true }
        return false
    }
}

extension KBMessage {
    var isPipelineErrorMessage: Bool {
        role == .assistant && PipelineErrorMessageClassifier.isPipelineErrorMessage(content)
    }
}
