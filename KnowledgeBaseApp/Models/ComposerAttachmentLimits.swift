import Foundation

/// Client-side limits aligned with KB App API (`MAX_ATTACHMENTS_PER_MESSAGE`).
enum ComposerAttachmentLimits {
    static let maxFileAttachments = 10
    /// Raised for short screen recordings / gallery videos (was 25 MB).
    static let maxBytesPerAttachment: Int64 = 100 * 1024 * 1024

    enum ValidationError: Equatable {
        case tooManyFiles(max: Int)
        case fileTooLarge(filename: String, maxBytes: Int64)

        var message: String {
            switch self {
            case .tooManyFiles(let max):
                return L10n.format("composer.attachment_limit_files", max)
            case .fileTooLarge(let filename, let maxBytes):
                let limit = ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)
                return L10n.format("composer.attachment_limit_size", filename, limit)
            }
        }
    }

    static func validateAdding(
        currentAttachments: [PendingAttachment],
        newAttachment: PendingAttachment
    ) -> ValidationError? {
        if currentAttachments.count >= maxFileAttachments {
            return .tooManyFiles(max: maxFileAttachments)
        }
        if let size = newAttachment.fileSize, size > maxBytesPerAttachment {
            return .fileTooLarge(filename: newAttachment.filename, maxBytes: maxBytesPerAttachment)
        }
        return nil
    }

    static func remainingFileSlots(currentCount: Int) -> Int {
        max(0, maxFileAttachments - currentCount)
    }
}
