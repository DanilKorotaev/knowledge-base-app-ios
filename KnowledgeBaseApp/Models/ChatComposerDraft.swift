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
        case compose(ChatComposerDraft)
        case unsupported(String)
    }

    static func route(for draft: ChatComposerDraft) -> Route {
        let attachmentCount = draft.attachments.count
        let voiceCount = draft.voiceClips.count

        if attachmentCount == 0 && voiceCount == 0 {
            guard !draft.trimmedText.isEmpty else {
                return .unsupported(L10n.string("composer.add_content"))
            }
            return .textOnly(draft.trimmedText)
        }

        if attachmentCount == 1 && voiceCount == 0 && draft.trimmedText.isEmpty {
            return .singleAttachment(draft.attachments[0])
        }

        if voiceCount == 1 && attachmentCount == 0 {
            let text = draft.trimmedText.isEmpty ? draft.voiceClips[0].transcriptionSegment : draft.trimmedText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .unsupported(L10n.string("composer.voice_transcription_failed"))
            }
            return .singleVoice(draft.voiceClips[0], text: text)
        }

        guard draft.canSend else {
            return .unsupported(L10n.string("composer.add_content"))
        }
        return .compose(draft)
    }
}
