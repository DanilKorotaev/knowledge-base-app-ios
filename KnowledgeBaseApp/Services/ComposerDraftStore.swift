import Foundation

struct LoadedComposerDraft: Equatable {
    var draft: ChatComposerDraft
    var pendingVoiceCaptures: [PendingVoiceCapture]
}

protocol ComposerDraftStoreProtocol: Sendable {
    func load(sessionId: String) -> LoadedComposerDraft?
    @discardableResult
    func save(
        sessionId: String,
        draft: ChatComposerDraft,
        pendingVoiceCaptures: [PendingVoiceCapture]
    ) -> LoadedComposerDraft?
    /// Appends text/attachments into an existing draft (or creates one). Does not replace prior content.
    @discardableResult
    func merge(
        sessionId: String,
        text: String?,
        attachments: [PendingAttachment]
    ) -> LoadedComposerDraft?
    func clear(sessionId: String)
}

/// Persists unsent composer content per chat session until a message is sent successfully.
final class ComposerDraftStore: ComposerDraftStoreProtocol, @unchecked Sendable {
    static let shared = ComposerDraftStore()

    private struct Manifest: Codable {
        var text: String
        var attachments: [StoredAttachment]
        var voiceClips: [StoredVoiceClip]
        var pendingVoiceCaptures: [StoredPendingCapture]
    }

    private struct StoredAttachment: Codable {
        let id: String
        let storedFilename: String
        let kind: PendingAttachmentKind
        let filename: String
        let mimeType: String
        let fileSize: Int64?
    }

    private struct StoredVoiceClip: Codable {
        let id: String
        let storedFilename: String
        let transcriptionSegment: String
    }

    private struct StoredPendingCapture: Codable {
        let id: String
        let storedFilename: String
        let state: PendingVoiceCaptureState
    }

    private let lock = NSRecursiveLock()
    private let fileManager: FileManager
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = AppGroupContainer.composerDraftsDirectory(fileManager: fileManager)
        }
        try? fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
    }

    func load(sessionId: String) -> LoadedComposerDraft? {
        lock.lock()
        defer { lock.unlock() }

        let sessionDir = sessionDirectoryURL(sessionId: sessionId)
        let manifestURL = sessionDir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? decoder.decode(Manifest.self, from: data) else {
            return nil
        }

        let filesDir = filesDirectoryURL(sessionId: sessionId)
        var draft = ChatComposerDraft()
        draft.text = manifest.text

        draft.attachments = manifest.attachments.compactMap { stored in
            let url = filesDir.appendingPathComponent(stored.storedFilename)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return PendingAttachment(
                id: stored.id,
                localURL: url,
                kind: stored.kind,
                filename: stored.filename,
                mimeType: stored.mimeType,
                fileSize: stored.fileSize
            )
        }

        draft.voiceClips = manifest.voiceClips.compactMap { stored in
            let url = filesDir.appendingPathComponent(stored.storedFilename)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return PendingVoiceClip(
                id: stored.id,
                audioURL: url,
                transcriptionSegment: stored.transcriptionSegment
            )
        }

        let pendingVoiceCaptures = manifest.pendingVoiceCaptures.compactMap { stored -> PendingVoiceCapture? in
            let url = filesDir.appendingPathComponent(stored.storedFilename)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return PendingVoiceCapture(id: stored.id, audioURL: url, state: stored.state)
        }

        let loaded = LoadedComposerDraft(draft: draft, pendingVoiceCaptures: pendingVoiceCaptures)
        if isEffectivelyEmpty(loaded) {
            removeSessionDirectory(sessionId: sessionId)
            return nil
        }
        return loaded
    }

    @discardableResult
    func save(
        sessionId: String,
        draft: ChatComposerDraft,
        pendingVoiceCaptures: [PendingVoiceCapture]
    ) -> LoadedComposerDraft? {
        lock.lock()
        defer { lock.unlock() }

        let candidate = LoadedComposerDraft(draft: draft, pendingVoiceCaptures: pendingVoiceCaptures)
        if isEffectivelyEmpty(candidate) {
            removeSessionDirectory(sessionId: sessionId)
            return nil
        }

        let sessionDir = sessionDirectoryURL(sessionId: sessionId)
        let filesDir = filesDirectoryURL(sessionId: sessionId)
        try? fileManager.createDirectory(at: filesDir, withIntermediateDirectories: true)

        var normalizedDraft = draft
        var normalizedPending = pendingVoiceCaptures

        do {
            normalizedDraft.attachments = try draft.attachments.map { attachment in
                let storedFilename = try adoptFile(at: attachment.localURL, into: filesDir)
                return PendingAttachment(
                    id: attachment.id,
                    localURL: filesDir.appendingPathComponent(storedFilename),
                    kind: attachment.kind,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    fileSize: attachment.fileSize
                )
            }

            normalizedDraft.voiceClips = try draft.voiceClips.map { clip in
                let storedFilename = try adoptFile(at: clip.audioURL, into: filesDir)
                return PendingVoiceClip(
                    id: clip.id,
                    audioURL: filesDir.appendingPathComponent(storedFilename),
                    transcriptionSegment: clip.transcriptionSegment
                )
            }

            normalizedPending = try pendingVoiceCaptures.map { capture in
                let storedFilename = try adoptFile(at: capture.audioURL, into: filesDir)
                return PendingVoiceCapture(
                    id: capture.id,
                    audioURL: filesDir.appendingPathComponent(storedFilename),
                    state: capture.state
                )
            }
        } catch {
            return nil
        }

        let manifest = Manifest(
            text: normalizedDraft.text,
            attachments: normalizedDraft.attachments.map {
                StoredAttachment(
                    id: $0.id,
                    storedFilename: $0.localURL.lastPathComponent,
                    kind: $0.kind,
                    filename: $0.filename,
                    mimeType: $0.mimeType,
                    fileSize: $0.fileSize
                )
            },
            voiceClips: normalizedDraft.voiceClips.map {
                StoredVoiceClip(
                    id: $0.id,
                    storedFilename: $0.audioURL.lastPathComponent,
                    transcriptionSegment: $0.transcriptionSegment
                )
            },
            pendingVoiceCaptures: normalizedPending.map {
                StoredPendingCapture(
                    id: $0.id,
                    storedFilename: $0.audioURL.lastPathComponent,
                    state: $0.state
                )
            }
        )

        guard let data = try? encoder.encode(manifest) else { return nil }
        try? fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? data.write(to: sessionDir.appendingPathComponent("manifest.json"), options: .atomic)

        return LoadedComposerDraft(draft: normalizedDraft, pendingVoiceCaptures: normalizedPending)
    }

    @discardableResult
    func merge(
        sessionId: String,
        text: String?,
        attachments: [PendingAttachment]
    ) -> LoadedComposerDraft? {
        let incoming = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let existing = load(sessionId: sessionId)
        let merged = ComposerDraftMerger.merge(
            existing: existing?.draft ?? ChatComposerDraft(),
            text: incoming.isEmpty ? nil : incoming,
            attachments: attachments
        )
        return save(
            sessionId: sessionId,
            draft: merged,
            pendingVoiceCaptures: existing?.pendingVoiceCaptures ?? []
        )
    }

    func clear(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        removeSessionDirectory(sessionId: sessionId)
    }

    // MARK: - Private

    private func isEffectivelyEmpty(_ loaded: LoadedComposerDraft) -> Bool {
        loaded.draft.trimmedText.isEmpty
            && loaded.draft.attachments.isEmpty
            && loaded.draft.voiceClips.isEmpty
            && loaded.pendingVoiceCaptures.isEmpty
    }

    private func sessionDirectoryURL(sessionId: String) -> URL {
        let safeName = sessionId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sessionId
        return baseURL.appendingPathComponent(safeName, isDirectory: true)
    }

    private func filesDirectoryURL(sessionId: String) -> URL {
        sessionDirectoryURL(sessionId: sessionId).appendingPathComponent("files", isDirectory: true)
    }

    private func removeSessionDirectory(sessionId: String) {
        let dir = sessionDirectoryURL(sessionId: sessionId)
        try? fileManager.removeItem(at: dir)
    }

    private func adoptFile(at sourceURL: URL, into filesDirectory: URL) throws -> String {
        let filesRoot = filesDirectory.path
        if sourceURL.path.hasPrefix(filesRoot) {
            return sourceURL.lastPathComponent
        }

        let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        let dest = filesDirectory.appendingPathComponent(name)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: sourceURL, to: dest)
        return name
    }
}
