import Foundation

/// Appends text/attachments onto an existing draft without mutating storage.
enum ComposerDraftMerger {
    static func merge(
        existing: ChatComposerDraft,
        text: String?,
        attachments: [PendingAttachment]
    ) -> ChatComposerDraft {
        var draft = existing
        let incoming = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !incoming.isEmpty {
            if draft.trimmedText.isEmpty {
                draft.text = incoming
            } else if draft.text.hasSuffix("\n") {
                draft.text += incoming
            } else {
                draft.text += "\n" + incoming
            }
        }
        for attachment in attachments {
            if ComposerAttachmentLimits.validateAdding(
                currentAttachments: draft.attachments,
                newAttachment: attachment
            ) != nil {
                break
            }
            draft.attachments.append(attachment)
        }
        return draft
    }
}
