import Foundation

enum MessageRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
    case system
}

enum ContentFormat: String, Codable, Sendable, Equatable {
    case markdown
    case html
    case plain
}

struct KBMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let role: MessageRole
    let content: String
    let createdAt: Date?
    let attachments: [KBAttachment]?
    let contentFormat: ContentFormat?
    let transcription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
        case attachments
        case contentFormat = "content_format"
        case transcription
    }

    init(
        id: String,
        role: MessageRole,
        content: String,
        createdAt: Date?,
        attachments: [KBAttachment]? = nil,
        contentFormat: ContentFormat? = nil,
        transcription: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
        self.contentFormat = contentFormat
        self.transcription = transcription
    }

    var imageAttachments: [KBAttachment] {
        attachments?.filter(\.isImage) ?? []
    }

    var voiceAttachments: [KBAttachment] {
        attachments?.filter(\.isVoice) ?? []
    }

    var effectiveTranscription: String? {
        if let transcription, !transcription.isEmpty { return transcription }
        return voiceAttachments.compactMap(\.transcription).first
    }

    /// True when the message is only voice attachment(s) with no images or extra text.
    var isVoiceOnly: Bool {
        guard !voiceAttachments.isEmpty, imageAttachments.isEmpty else { return false }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        if text.hasPrefix("🎤") { return true }
        if text.lowercased() == "voice note" { return true }
        return contentDuplicatesVoiceTranscription
    }

    /// Single voice, no images — Telegram-style collapsible transcription under the player.
    var isSingleVoiceOnlyMessage: Bool {
        isVoiceOnly && voiceAttachments.count == 1
    }

    /// Photo + voice, multiple voices, etc.
    var isCompositeAttachmentMessage: Bool {
        let hasVoice = !voiceAttachments.isEmpty
        let hasImages = !imageAttachments.isEmpty
        if hasVoice && hasImages { return true }
        if voiceAttachments.count > 1 { return true }
        return false
    }

    /// Combined transcription from voice attachment(s) and message-level field.
    var composedVoiceTranscription: String? {
        let fromAttachments = voiceAttachments
            .compactMap { $0.transcription?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if fromAttachments.count > 1 {
            return fromAttachments.joined(separator: "\n\n")
        }
        if let single = fromAttachments.first {
            return single
        }
        if let tr = transcription?.trimmingCharacters(in: .whitespacesAndNewlines), !tr.isEmpty {
            return tr
        }
        return nil
    }

    /// Text shown under attachments; nil hides the text block entirely.
    var bubbleTextContent: String? {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if isVoiceOnly { return nil }

        if isCompositeAttachmentMessage {
            let supplemental = stripEmbeddedVoiceTranscriptions(from: text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !voiceAttachments.isEmpty {
                return supplemental.isEmpty ? nil : supplemental
            }
            var sections: [String] = []
            if let voiceBlock = composedVoiceTranscription {
                sections.append(voiceBlock)
            }
            if !supplemental.isEmpty {
                sections.append(supplemental)
            } else if sections.isEmpty, !text.isEmpty {
                sections.append(text)
            }
            let result = sections.joined(separator: "\n\n")
            return result.isEmpty ? nil : result
        }

        guard !text.isEmpty else { return nil }
        if contentDuplicatesVoiceTranscription { return nil }
        return text
    }

    private func stripEmbeddedVoiceTranscriptions(from text: String) -> String {
        var result = text
        for voice in voiceAttachments {
            guard let tr = voice.transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !tr.isEmpty else { continue }
            result = result.replacingOccurrences(of: tr, with: "")
        }
        if let tr = transcription?.trimmingCharacters(in: .whitespacesAndNewlines), !tr.isEmpty {
            result = result.replacingOccurrences(of: tr, with: "")
        }
        return result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// True when `content` is empty, a voice marker, or duplicates the voice transcription (stored in DB as message text).
    /// Kept for tests; prefer `isVoiceOnly` in UI.
    var contentDuplicatesVoiceTranscription: Bool {
        guard !voiceAttachments.isEmpty, let transcription = effectiveTranscription else { return false }
        let contentNorm = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trNorm = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contentNorm.isEmpty, !trNorm.isEmpty else { return false }
        if contentNorm == trNorm { return true }
        if contentNorm.localizedCaseInsensitiveCompare(trNorm) == .orderedSame { return true }
        // Server may store a slightly shorter `content` than attachment transcription.
        let shorter = contentNorm.count <= trNorm.count ? contentNorm : trNorm
        let longer = contentNorm.count > trNorm.count ? contentNorm : trNorm
        return longer.hasPrefix(shorter) && shorter.count >= 20
            && Double(shorter.count) / Double(longer.count) >= 0.85
    }

    var resolvedContentFormat: ContentFormat {
        contentFormat ?? (role == .assistant ? .markdown : .plain)
    }
}
