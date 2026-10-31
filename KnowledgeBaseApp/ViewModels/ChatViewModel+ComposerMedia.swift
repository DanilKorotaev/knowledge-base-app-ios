import Foundation
import UIKit

extension ChatViewModel {
    func removeAttachment(id: String) {
        if let attachment = composerDraft.attachments.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: attachment.localURL)
        }
        composerDraft.attachments.removeAll { $0.id == id }
        scheduleComposerDraftSave()
    }

    func removeVoiceClip(id: String) {
        if let clip = composerDraft.voiceClips.first(where: { $0.id == id }) {
            PendingVoiceStore.deleteRecording(at: clip.audioURL)
        }
        composerDraft.voiceClips.removeAll { $0.id == id }
        scheduleComposerDraftSave()
    }

    func discardPendingVoiceCapture(id: String) {
        if let capture = pendingVoiceCaptures.first(where: { $0.id == id }) {
            PendingVoiceStore.deleteRecording(at: capture.audioURL)
        }
        pendingVoiceCaptures.removeAll { $0.id == id }
        syncTranscribingVoiceFlag()
        scheduleComposerDraftSave()
    }

    func retryPendingVoiceCaptureTranscription(id: String) async {
        guard let index = pendingVoiceCaptures.firstIndex(where: { $0.id == id }) else { return }
        pendingVoiceCaptures[index].state = .transcribing
        syncTranscribingVoiceFlag()
        await transcribePendingVoiceCapture(id: id)
    }

    @discardableResult
    func addPendingAttachment(_ attachment: PendingAttachment) -> Bool {
        tryAddPendingAttachment(attachment)
    }

    @discardableResult
    func addPhotoData(_ data: Data, filename: String = "photo.jpg") -> Bool {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: path)
            return tryAddPendingAttachment(
                PendingAttachment(
                    localURL: path,
                    kind: .image,
                    filename: filename,
                    mimeType: "image/jpeg",
                    fileSize: Int64(data.count)
                )
            )
        } catch {
            reportError(error.localizedDescription)
            return false
        }
    }

    var remainingComposerAttachmentSlots: Int {
        ComposerAttachmentLimits.remainingFileSlots(currentCount: composerDraft.attachments.count)
    }

    func reportAttachmentLimitReached() {
        reportError(
            ComposerAttachmentLimits.ValidationError.tooManyFiles(
                max: ComposerAttachmentLimits.maxFileAttachments
            ).message
        )
    }

    @discardableResult
    private func tryAddPendingAttachment(_ attachment: PendingAttachment) -> Bool {
        if let error = ComposerAttachmentLimits.validateAdding(
            currentAttachments: composerDraft.attachments,
            newAttachment: attachment
        ) {
            reportError(error.message)
            cleanupRejectedAttachment(at: attachment.localURL)
            return false
        }
        composerDraft.attachments.append(attachment)
        scheduleComposerDraftSave()
        return true
    }

    private func cleanupRejectedAttachment(at url: URL) {
        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        if url.standardizedFileURL.path.hasPrefix(tempRoot.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @discardableResult
    func attachDebugLogFile(from sourceURL: URL) -> Bool {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try Self.copyLogFileTruncatingIfNeeded(
                from: sourceURL,
                to: dest,
                maxBytes: ComposerAttachmentLimits.maxBytesPerAttachment
            )
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?
                .int64Value
            let attachment = PendingAttachment(
                localURL: dest,
                kind: .file,
                filename: sourceURL.lastPathComponent,
                mimeType: "text/plain",
                fileSize: size
            )
            return tryAddPendingAttachment(attachment)
        } catch {
            reportError(error.localizedDescription)
            return false
        }
    }

    /// Keeps the end of oversized debug logs so they still fit the composer limit.
    private static func copyLogFileTruncatingIfNeeded(from source: URL, to dest: URL, maxBytes: Int64) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: source.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        if size <= maxBytes {
            try FileManager.default.copyItem(at: source, to: dest)
            return
        }
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let keep = maxBytes - 256
        try handle.seek(toOffset: UInt64(max(0, size - keep)))
        var data = try handle.readToEnd() ?? Data()
        let header = Data(
            "… [truncated; showing last \(keep) of \(size) bytes]\n\n".utf8
        )
        data = header + data
        try data.write(to: dest, options: .atomic)
    }

    func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            reportError("Could not encode photo.")
            return
        }
        addPhotoData(data, filename: "camera.jpg")
    }

    func addFiles(from urls: [URL]) async {
        var skippedLimit = false
        for url in urls {
            if remainingComposerAttachmentSlots == 0 {
                skippedLimit = true
                break
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?
                    .int64Value
                let data = try? Data(contentsOf: dest)
                // Screenshots / HEIC drops often have fake extensions — normalize via importer.
                if let data,
                   let normalized = ClipboardMediaImporter.attachment(
                       fromImageData: data,
                       filename: url.lastPathComponent
                   ) {
                    try? FileManager.default.removeItem(at: dest)
                    if !tryAddPendingAttachment(normalized) {
                        try? FileManager.default.removeItem(at: normalized.localURL)
                        if remainingComposerAttachmentSlots == 0 {
                            skippedLimit = true
                        }
                    }
                    continue
                }
                let mime = dest.kbPreferredMIMEType
                let kind = PendingAttachmentKind.infer(
                    mimeType: mime,
                    filenameExtension: dest.pathExtension
                )
                let attachment = PendingAttachment(
                    localURL: dest,
                    kind: kind,
                    filename: url.lastPathComponent,
                    mimeType: mime,
                    fileSize: size
                )
                if !tryAddPendingAttachment(attachment) {
                    try? FileManager.default.removeItem(at: dest)
                    if remainingComposerAttachmentSlots == 0 {
                        skippedLimit = true
                    }
                }
            } catch {
                reportError(error.localizedDescription)
            }
        }
        if skippedLimit {
            reportAttachmentLimitReached()
        }
    }

    func enqueueVoiceRecording(audioURL: URL) async {
        let captureID: String
        do {
            let persistedURL: URL
            if PendingVoiceStore.isManagedURL(audioURL) {
                persistedURL = audioURL
            } else {
                persistedURL = try PendingVoiceStore.persistRecording(from: audioURL)
                if persistedURL != audioURL {
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
            let capture = PendingVoiceCapture(audioURL: persistedURL, state: .transcribing)
            captureID = capture.id
            pendingVoiceCaptures.append(capture)
        } catch {
            errorMessage = VoicePipelineErrorMessage.forTranscription(error)
            return
        }

        syncTranscribingVoiceFlag()
        await transcribePendingVoiceCapture(id: captureID)
        scheduleComposerDraftSave()
    }

    func transcribePendingVoiceCapture(id: String) async {
        guard let index = pendingVoiceCaptures.firstIndex(where: { $0.id == id }) else { return }
        let audioURL = pendingVoiceCaptures[index].audioURL
        pendingVoiceCaptures[index].state = .transcribing
        syncTranscribingVoiceFlag()

        do {
            let transcription = try await client.transcribeVoiceRecording(audioFileURL: audioURL)
            guard pendingVoiceCaptures.contains(where: { $0.id == id }) else { return }
            pendingVoiceCaptures.removeAll { $0.id == id }
            let clip = PendingVoiceClip(audioURL: audioURL, transcriptionSegment: transcription)
            composerDraft.voiceClips.append(clip)
            composerDraft.appendTranscription(transcription)
        } catch {
            guard let failedIndex = pendingVoiceCaptures.firstIndex(where: { $0.id == id }) else { return }
            pendingVoiceCaptures[failedIndex].state = .failed(
                message: VoicePipelineErrorMessage.forTranscription(error)
            )
        }

        syncTranscribingVoiceFlag()
        scheduleComposerDraftSave()
    }

    func syncTranscribingVoiceFlag() {
        isTranscribingVoice = pendingVoiceCaptures.contains {
            if case .transcribing = $0.state { return true }
            return false
        }
    }
}
