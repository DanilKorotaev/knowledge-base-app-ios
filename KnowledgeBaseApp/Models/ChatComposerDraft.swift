import Foundation

enum PendingAttachmentKind: String, Equatable, Codable {
    case image
    case file
}

struct PendingAttachment: Identifiable, Equatable {
    let id: String
    let localURL: URL
    let kind: PendingAttachmentKind
    let filename: String
    let mimeType: String
    var fileSize: Int64?

    init(
        id: String = UUID().uuidString,
        localURL: URL,
        kind: PendingAttachmentKind,
        filename: String,
        mimeType: String,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.localURL = localURL
        self.kind = kind
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
    }
}

struct PendingVoiceClip: Identifiable, Equatable {
    let id: String
    let audioURL: URL
    var transcriptionSegment: String

    init(
        id: String = UUID().uuidString,
        audioURL: URL,
        transcriptionSegment: String
    ) {
        self.id = id
        self.audioURL = audioURL
        self.transcriptionSegment = transcriptionSegment
    }
}

struct ChatComposerDraft: Equatable {
    var text: String = ""
    var attachments: [PendingAttachment] = []
    var voiceClips: [PendingVoiceClip] = []

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedText.isEmpty || !attachments.isEmpty || !voiceClips.isEmpty
    }

    mutating func appendTranscription(_ segment: String) {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if text.isEmpty {
            text = trimmed
        } else if text.hasSuffix("\n") {
            text += trimmed
        } else {
            text += " "
            text += trimmed
        }
    }

    mutating func clear() {
        text = ""
        attachments = []
        voiceClips = []
    }
}

enum ChatComposerSendPlanner {
    enum Route: Equatable {
        case textOnly(String)
        case singleAttachment(PendingAttachment)
        case singleVoice(PendingVoiceClip, text: String)
        case unsupported(String)
    }

    static func route(for draft: ChatComposerDraft) -> Route {
        let attachmentCount = draft.attachments.count
        let voiceCount = draft.voiceClips.count

        if attachmentCount + voiceCount > 1 {
            return .unsupported(
                "Пока можно отправить только один файл или одно голосовое за раз. Несколько вложений — после обновления API compose."
            )
        }
        if attachmentCount > 0 && voiceCount > 0 {
            return .unsupported(
                "Файл и голосовое в одном сообщении пока не поддерживаются — дождитесь API compose."
            )
        }
        if attachmentCount == 1, !draft.trimmedText.isEmpty {
            return .unsupported(
                "Текст вместе с файлом пока не поддерживается — отправьте отдельно или дождитесь API compose."
            )
        }
        if let attachment = draft.attachments.first {
            return .singleAttachment(attachment)
        }
        if let clip = draft.voiceClips.first {
            let text = draft.trimmedText.isEmpty ? clip.transcriptionSegment : draft.trimmedText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .unsupported("Голосовое сообщение не удалось расшифровать.")
            }
            return .singleVoice(clip, text: text)
        }
        guard !draft.trimmedText.isEmpty else {
            return .unsupported("Добавьте текст, файл или голосовое.")
        }
        return .textOnly(draft.trimmedText)
    }
}
