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

    /// True when `content` is empty, a voice marker, or duplicates the voice transcription (stored in DB as message text).
    var isVoiceOnly: Bool {
        guard !voiceAttachments.isEmpty else { return false }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        if text.hasPrefix("🎤") { return true }
        if text.lowercased() == "voice note" { return true }
        return contentDuplicatesVoiceTranscription
    }

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
