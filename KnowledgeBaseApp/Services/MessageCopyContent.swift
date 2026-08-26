import Foundation
import UIKit

enum MessageCopyContent {
    /// Full message text for clipboard / copy sheet (source markdown/plain; no attachments).
    static func text(for message: KBMessage) -> String? {
        if message.isVoiceOnly,
           let transcription = message.composedVoiceTranscription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !transcription.isEmpty {
            return transcription
        }

        if let bubble = message.bubbleTextContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bubble.isEmpty {
            return bubble
        }

        let raw = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty, !isVoiceMarker(raw) {
            return raw
        }

        if let transcription = message.composedVoiceTranscription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !transcription.isEmpty {
            return transcription
        }
        return nil
    }

    @discardableResult
    static func copyToPasteboard(_ message: KBMessage) -> Bool {
        guard let text = text(for: message), !text.isEmpty else { return false }
        UIPasteboard.general.string = text
        return true
    }

    private static func isVoiceMarker(_ text: String) -> Bool {
        text == "🎤" || text.hasPrefix("🎤 ")
    }
}
