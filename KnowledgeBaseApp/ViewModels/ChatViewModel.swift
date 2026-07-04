import Foundation
import UIKit

/// Drives `ChatView` scroll without implicit `onChange` heuristics.
enum ChatScrollIntent: Equatable {
    case none
    case scrollToBottom
    case preserve(messageId: String)
}

@MainActor
@Observable
final class ChatViewModel {
    static let pageSize = 5
    static let maxMessagePageLimit = 100

    let session: KBSession
    var messages: [KBMessage] = []
    var composerDraft = ChatComposerDraft()
    let useKnowledgeBase: Bool
    var isLoading = false
    var isLoadingOlder = false
    var isSending = false
    var isTranscribingVoice = false
    var pendingVoiceCaptures: [PendingVoiceCapture] = []
    var errorMessage: String?
    var syncStatus: SyncStatus = .idle
    var totalCount = 0
    var hasMoreOlder = false
    var scrollIntent: ChatScrollIntent = .none
    /// In-flight assistant reply UI (spinner, streaming text, finalize).
    var assistantReplyPhase: AssistantReplyPhase = .idle
    /// Cursor tool progress label from SSE `activity` events (hidden after first text delta).
    var cursorActivityLabel: String?

    private var streamRevealContinuation: CheckedContinuation<Void, Never>?
    private var isPollingForReply = false

    private let client: ChatAPIClientProtocol
    private let messageCache: MessageCacheStoreProtocol
    private let composerDraftStore: ComposerDraftStoreProtocol
    private let sessionKBModeStore: SessionKBModeStoreProtocol
    private var composerDraftSaveTask: Task<Void, Never>?

    /// Backward-compatible alias for tests and legacy call sites.
    var draft: String {
        get { composerDraft.text }
        set { composerDraft.text = newValue }
    }

    var canSendComposer: Bool {
        composerDraft.canSend
            && !isSending
            && !isTranscribingVoice
            && !hasBlockingPendingVoiceCapture
    }

    private var hasBlockingPendingVoiceCapture: Bool {
        pendingVoiceCaptures.contains {
            switch $0.state {
            case .transcribing, .failed:
                return true
            }
        }
    }

    init(
        session: KBSession,
        client: ChatAPIClientProtocol,
        messageCache: MessageCacheStoreProtocol = FileOfflineCacheStore.shared,
        composerDraftStore: ComposerDraftStoreProtocol = ComposerDraftStore.shared,
        sessionKBModeStore: SessionKBModeStoreProtocol = SessionKBModeStore.shared
    ) {
        self.session = session
        self.client = client
        self.messageCache = messageCache
        self.composerDraftStore = composerDraftStore
        self.sessionKBModeStore = sessionKBModeStore
        self.useKnowledgeBase = sessionKBModeStore.useKnowledgeBase(for: session)
        restoreComposerDraftIfNeeded()
    }

    func load() async {
        bootstrapFromCacheIfNeeded()
        let hadCachedMessages = !messages.isEmpty
        if hadCachedMessages {
            syncStatus = .refreshing
        } else {
            isLoading = true
        }
        errorMessage = nil
        scrollIntent = .none
        ChatPaginationLogger.initialLoadStarted(sessionId: session.id)
        defer { isLoading = false }
        await refreshFromNetwork(hadLocalData: hadCachedMessages, kind: "initial")
        await resumeAwaitingReplyIfNeeded()
    }

    /// Background refresh (pull-to-refresh, app became active).
    func refresh() async {
        let hadLocalData = !messages.isEmpty
        if hadLocalData {
            syncStatus = .refreshing
        }
        await refreshFromNetwork(hadLocalData: hadLocalData, kind: "refresh")
    }

    private func refreshFromNetwork(hadLocalData: Bool, kind: String) async {
        guard NetworkPathMonitor.shared.isOnline else {
            if hadLocalData {
                syncStatus = .offline(lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id))
                ChatPaginationLogger.loadSkippedOffline(kind)
            } else {
                errorMessage = "Нет подключения к сети"
                syncStatus = .offline(lastSyncedAt: nil)
                ChatPaginationLogger.loadSkippedOffline(kind)
            }
            return
        }

        do {
            let limit = refreshFetchLimit(kind: kind, hadLocalData: hadLocalData)
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: limit,
                beforeMessageId: nil
            )
            apply(
                page: page,
                requestedLimit: limit,
                kind: kind == "initial" ? "initial" : "reloadLatest"
            )
            syncStatus = .upToDate(lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id) ?? Date())
        } catch {
            let lastSynced = messageCache.lastSyncedAt(sessionId: session.id)
            if hadLocalData {
                syncStatus = SyncNetworkError.failureStatus(
                    error: error,
                    lastSyncedAt: lastSynced,
                    isPathOnline: NetworkPathMonitor.shared.isOnline
                )
            } else {
                errorMessage = error.localizedDescription
                syncStatus = SyncNetworkError.failureStatus(
                    error: error,
                    lastSyncedAt: nil,
                    isPathOnline: NetworkPathMonitor.shared.isOnline
                )
            }
            ChatPaginationLogger.loadFailed(kind, error: error.localizedDescription)
        }
    }

    private func bootstrapFromCacheIfNeeded() {
        guard messages.isEmpty,
              let cached = messageCache.loadWindow(sessionId: session.id),
              !cached.messages.isEmpty else { return }
        apply(page: cached, requestedLimit: cached.messages.count, kind: "cache")
    }

    private func refreshFetchLimit(kind: String, hadLocalData: Bool) -> Int {
        if kind == "initial", hadLocalData {
            return normalizedFetchLimit(messages.count + 2)
        }
        if kind == "initial" {
            return Self.pageSize
        }
        return normalizedFetchLimit(messages.count + 2)
    }

    func loadOlder() async {
        if !hasMoreOlder {
            ChatPaginationLogger.requestBlocked("hasMoreOlder=false", context: "viewModel.loadOlder")
            return
        }
        if isLoadingOlder {
            ChatPaginationLogger.requestBlocked("isLoadingOlder=true", context: "viewModel.loadOlder")
            return
        }
        if isLoading {
            ChatPaginationLogger.requestBlocked("isLoading=true", context: "viewModel.loadOlder")
            return
        }
        guard let anchorId = messages.first?.id else {
            ChatPaginationLogger.requestBlocked("messages.first=nil", context: "viewModel.loadOlder")
            return
        }
        guard NetworkPathMonitor.shared.isOnline else {
            if loadOlderFromCacheIfPossible() {
                return
            }
            syncStatus = .offline(lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id))
            ChatPaginationLogger.loadSkippedOffline("older")
            return
        }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: Self.pageSize,
                beforeMessageId: anchorId
            )
            guard !page.messages.isEmpty else {
                hasMoreOlder = false
                ChatPaginationLogger.requestBlocked("empty page from API", context: "viewModel.loadOlder")
                return
            }
            let older = clamp(page.messages, to: Self.pageSize)
            messages = older + messages
            totalCount = page.total
            hasMoreOlder = page.hasMoreOlder
            scrollIntent = .preserve(messageId: anchorId)
            persistMessageWindow()
            ChatPaginationLogger.pageApplied(
                kind: "older",
                messageIds: page.messages.map(\.id),
                total: page.total,
                hasMoreOlder: page.hasMoreOlder,
                windowCount: messages.count
            )
        } catch {
            if SyncNetworkError.isOffline(error) || !NetworkPathMonitor.shared.isOnline {
                syncStatus = .offline(lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id))
                ChatPaginationLogger.loadSkippedOffline("older")
            } else {
                errorMessage = error.localizedDescription
                ChatPaginationLogger.loadFailed("older", error: error.localizedDescription)
            }
        }
    }

    func acknowledgeScrollIntent() {
        scrollIntent = .none
    }

    /// Called when the streaming bubble finishes its typewriter reveal in `finalizing`.
    func completeStreamRevealAnimation() {
        streamRevealContinuation?.resume()
        streamRevealContinuation = nil
    }

    func waitForStreamRevealAnimation() async {
        guard case .finalizing(let text) = assistantReplyPhase, !text.isEmpty else { return }
        let timeoutMs = min(30_000, max(800, text.count * 28))

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    self.streamRevealContinuation = continuation
                }
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(timeoutMs))
                await MainActor.run {
                    self.completeStreamRevealAnimation()
                }
            }
            _ = await group.next()
            group.cancelAll()
        }
    }

    /// Applies streaming phase from voice send (`AssistantReplyPhaseNotification`).
    func applyExternalAssistantPhase(_ phase: AssistantReplyPhase, activityLabel: String? = nil) {
        assistantReplyPhase = phase
        if let activityLabel {
            cursorActivityLabel = activityLabel
        } else if !phase.showsPendingSpinner {
            cursorActivityLabel = nil
        }
        if phase.showsPlaceholder {
            scrollIntent = .scrollToBottom
        }
    }

    private func applyStreamUpdate(_ update: AssistantReplyStreamUpdate) {
        assistantReplyPhase = update.phase
        cursorActivityLabel = update.activityLabel
        scrollIntent = .scrollToBottom
    }

    func send() async {
        await sendComposed()
    }

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

    func addPendingAttachment(_ attachment: PendingAttachment) {
        composerDraft.attachments.append(attachment)
        scheduleComposerDraftSave()
    }

    func addPhotoData(_ data: Data, filename: String = "photo.jpg") {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: path)
            addPendingAttachment(
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
        }
    }

    func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            reportError("Could not encode photo.")
            return
        }
        addPhotoData(data, filename: "camera.jpg")
    }

    func addFiles(from urls: [URL]) async {
        for url in urls {
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
                let mime = dest.kbPreferredMIMEType
                let kind: PendingAttachmentKind = mime.hasPrefix("image/") ? .image : .file
                addPendingAttachment(
                    PendingAttachment(
                        localURL: dest,
                        kind: kind,
                        filename: url.lastPathComponent,
                        mimeType: mime,
                        fileSize: size
                    )
                )
            } catch {
                reportError(error.localizedDescription)
            }
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

    private func transcribePendingVoiceCapture(id: String) async {
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

    private func syncTranscribingVoiceFlag() {
        isTranscribingVoice = pendingVoiceCaptures.contains {
            if case .transcribing = $0.state { return true }
            return false
        }
    }

    func sendComposed() async {
        let route = ChatComposerSendPlanner.route(for: composerDraft)
        if case .unsupported(let message) = route {
            errorMessage = message
            return
        }

        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }

        // Clear composer immediately so voice/photo chips do not linger while the
        // assistant reply streams (including after backgrounding the app).
        detachComposerForSend()

        let succeeded: Bool
        switch route {
        case .unsupported:
            return
        case .textOnly(let text):
            succeeded = await sendStreamingText(text, optimisticContent: text)
        case .singleAttachment(let attachment):
            succeeded = await sendSingleAttachment(attachment)
        case .singleVoice(let clip, let text):
            succeeded = await sendSingleVoice(clip: clip, text: text)
        case .compose(let draft):
            succeeded = await sendComposedMessage(draft)
        }

        if succeeded {
            clearSavedComposerDraft()
        }
    }

    @discardableResult
    private func sendStreamingText(_ text: String, optimisticContent: String) async -> Bool {
        do {
            let optimisticUser = KBMessage(
                id: "kb-optimistic-\(UUID().uuidString)",
                role: .user,
                content: optimisticContent,
                createdAt: Date()
            )
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom

            let stream = try await client.streamTextMessage(
                sessionId: session.id,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { update in
                applyStreamUpdate(update)
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            return true
        } catch {
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            if await resumeAwaitingReplyIfNeeded() {
                return true
            }
            errorMessage = error.localizedDescription
            composerDraft.text = text
            scheduleComposerDraftSave()
            return false
        }
    }

    @discardableResult
    private func sendSingleAttachment(_ attachment: PendingAttachment) async -> Bool {
        let scoped = attachment.localURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                attachment.localURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: attachment.localURL,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            try? FileManager.default.removeItem(at: attachment.localURL)
            await reloadLatestWindow()
            return true
        } catch {
            errorMessage = error.localizedDescription
            composerDraft.attachments = [attachment]
            scheduleComposerDraftSave()
            return false
        }
    }

    @discardableResult
    private func sendSingleVoice(clip: PendingVoiceClip, text: String) async -> Bool {
        do {
            let optimisticUser = KBMessage(
                id: "kb-optimistic-\(UUID().uuidString)",
                role: .user,
                content: text,
                createdAt: Date()
            )
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom

            let stream = try await client.streamVoiceMessage(
                sessionId: session.id,
                audioFileURL: clip.audioURL,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { update in
                applyStreamUpdate(update)
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            PendingVoiceStore.deleteRecording(at: clip.audioURL)
            return true
        } catch {
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            if await resumeAwaitingReplyIfNeeded() {
                return true
            }
            errorMessage = VoicePipelineErrorMessage.forSend(error)
            composerDraft.voiceClips = [clip]
            composerDraft.appendTranscription(text)
            scheduleComposerDraftSave()
            return false
        }
    }

    @discardableResult
    private func sendComposedMessage(_ draft: ChatComposerDraft) async -> Bool {
        var scopedURLs: [URL] = []
        defer {
            for url in scopedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }

        for attachment in draft.attachments {
            if attachment.localURL.startAccessingSecurityScopedResource() {
                scopedURLs.append(attachment.localURL)
            }
        }

        let optimisticUser = buildOptimisticMessage(from: draft)
        do {
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            cursorActivityLabel = nil
            scrollIntent = .scrollToBottom

            let stream = try await client.streamComposedMessage(
                sessionId: session.id,
                draft: draft,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { update in
                applyStreamUpdate(update)
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            for attachment in draft.attachments {
                try? FileManager.default.removeItem(at: attachment.localURL)
            }
            for clip in draft.voiceClips {
                PendingVoiceStore.deleteRecording(at: clip.audioURL)
            }
            return true
        } catch {
            assistantReplyPhase = .idle
            cursorActivityLabel = nil
            if await resumeAwaitingReplyIfNeeded() {
                return true
            }
            errorMessage = VoicePipelineErrorMessage.forSend(error)
            composerDraft = draft
            scheduleComposerDraftSave()
            return false
        }
    }

    private func composedOptimisticPlaceholder(for draft: ChatComposerDraft) -> String {
        var parts: [String] = []
        if !draft.attachments.isEmpty {
            parts.append("📎 \(draft.attachments.count)")
        }
        if !draft.voiceClips.isEmpty {
            parts.append("🎤 \(draft.voiceClips.count)")
        }
        return parts.joined(separator: " ")
    }

    private func buildOptimisticMessage(from draft: ChatComposerDraft) -> KBMessage {
        var attachments: [KBAttachment] = []
        for item in draft.attachments {
            attachments.append(
                KBAttachment(
                    id: "optimistic-\(item.id)",
                    fileType: item.kind == .image ? "photo" : "document",
                    fileName: item.filename,
                    fileSize: item.fileSize.map(Int.init),
                    mimeType: item.mimeType,
                    downloadURL: item.localURL.absoluteString,
                    transcription: nil
                )
            )
        }
        for clip in draft.voiceClips {
            attachments.append(
                KBAttachment(
                    id: "optimistic-\(clip.id)",
                    fileType: "voice",
                    fileName: clip.audioURL.lastPathComponent,
                    fileSize: nil,
                    mimeType: "audio/mp4",
                    downloadURL: clip.audioURL.absoluteString,
                    transcription: clip.transcriptionSegment
                )
            )
        }
        let content = draft.trimmedText.isEmpty
            ? composedOptimisticPlaceholder(for: draft)
            : draft.text
        return KBMessage(
            id: "kb-optimistic-\(UUID().uuidString)",
            role: .user,
            content: content,
            createdAt: Date(),
            attachments: attachments.isEmpty ? nil : attachments
        )
    }

    func reloadLatestWindow() async {
        let limit = normalizedFetchLimit(messages.count + 2)
        syncStatus = messages.isEmpty ? .idle : .refreshing
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: limit,
                beforeMessageId: nil
            )
            apply(page: page, requestedLimit: limit, kind: "reloadLatest")
            scrollIntent = .scrollToBottom
            assistantReplyPhase = .idle
            syncStatus = .upToDate(lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id) ?? Date())
        } catch {
            if messages.isEmpty {
                errorMessage = error.localizedDescription
            }
            syncStatus = SyncNetworkError.failureStatus(
                error: error,
                lastSyncedAt: messageCache.lastSyncedAt(sessionId: session.id),
                isPathOnline: NetworkPathMonitor.shared.isOnline
            )
            ChatPaginationLogger.loadFailed("reloadLatest", error: error.localizedDescription)
        }
    }

    /// After SSE drops (background / leave chat), poll until the server persists the assistant reply.
    @discardableResult
    func resumeAwaitingReplyIfNeeded() async -> Bool {
        guard !isSending, !isPollingForReply else { return false }
        guard looksAwaitingAssistantReply else { return false }

        isPollingForReply = true
        assistantReplyPhase = .waiting
        defer { isPollingForReply = false }

        await pollUntilAssistantReply()
        return true
    }

    private var looksAwaitingAssistantReply: Bool {
        messages.last?.role == .user
    }

    private func pollUntilAssistantReply() async {
        let maxAttempts = 150
        let intervalNanoseconds: UInt64 = 2_000_000_000

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
            if Task.isCancelled { break }

            let limit = max(messages.count + 2, Self.pageSize)
            let normalizedLimit = normalizedFetchLimit(limit)
            do {
                let page = try await client.fetchMessagesPage(
                    sessionId: session.id,
                    limit: normalizedLimit,
                    beforeMessageId: nil
                )
                apply(page: page, requestedLimit: normalizedLimit, kind: "pollReply")
                if messages.last?.role == .assistant {
                    assistantReplyPhase = .idle
                    scrollIntent = .scrollToBottom
                    return
                }
            } catch {
                ChatPaginationLogger.loadFailed("pollReply", error: error.localizedDescription)
            }
        }
        assistantReplyPhase = .idle
    }

    func clearError() {
        errorMessage = nil
    }

    func scheduleComposerDraftSave() {
        composerDraftSaveTask?.cancel()
        composerDraftSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            persistComposerDraftNow()
        }
    }

    func persistComposerDraftNow() {
        composerDraftSaveTask?.cancel()
        guard shouldPersistComposerDraft else { return }
        if let normalized = composerDraftStore.save(
            sessionId: session.id,
            draft: composerDraft,
            pendingVoiceCaptures: pendingVoiceCaptures
        ) {
            composerDraft = normalized.draft
            pendingVoiceCaptures = normalized.pendingVoiceCaptures
            syncTranscribingVoiceFlag()
        }
    }

    private func restoreComposerDraftIfNeeded() {
        guard let loaded = composerDraftStore.load(sessionId: session.id) else { return }
        composerDraft = loaded.draft
        pendingVoiceCaptures = loaded.pendingVoiceCaptures
        syncTranscribingVoiceFlag()
        resumeInterruptedTranscriptions()
    }

    private func resumeInterruptedTranscriptions() {
        let transcribingIDs = pendingVoiceCaptures.compactMap { capture -> String? in
            if case .transcribing = capture.state { return capture.id }
            return nil
        }
        for id in transcribingIDs {
            Task { await transcribePendingVoiceCapture(id: id) }
        }
    }

    private var shouldPersistComposerDraft: Bool {
        !isSending && !assistantReplyPhase.showsPlaceholder && !isPollingForReply
    }

    /// Clears composer UI and on-disk draft when a send starts.
    /// Does not delete audio files — route handlers still reference them until upload finishes.
    private func detachComposerForSend() {
        composerDraftSaveTask?.cancel()
        composerDraft.clear()
        pendingVoiceCaptures = []
        syncTranscribingVoiceFlag()
        composerDraftStore.clear(sessionId: session.id)
    }

    private func clearSavedComposerDraft() {
        composerDraftSaveTask?.cancel()
        for clip in composerDraft.voiceClips {
            PendingVoiceStore.deleteRecording(at: clip.audioURL)
        }
        for capture in pendingVoiceCaptures {
            PendingVoiceStore.deleteRecording(at: capture.audioURL)
        }
        composerDraft.clear()
        pendingVoiceCaptures = []
        syncTranscribingVoiceFlag()
        composerDraftStore.clear(sessionId: session.id)
    }

    func reportError(_ message: String) {
        errorMessage = message
    }

    func sendAttachment(fileURL: URL, filename: String, mimeType: String) async {
        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: fileURL,
                filename: filename,
                mimeType: mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            await reloadLatestWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(page: KBMessagesPage, requestedLimit: Int, kind: String) {
        let nextMessages: [KBMessage]
        if kind == "cache" {
            nextMessages = page.messages
        } else if messages.isEmpty {
            nextMessages = clamp(page.messages, to: requestedLimit)
        } else {
            nextMessages = mergeOlderLoadedMessages(with: page.messages)
        }
        messages = nextMessages
        totalCount = page.total
        let hasOlderByCount = page.total > messages.count
        hasMoreOlder = page.hasMoreOlder || hasOlderByCount
        if kind != "cache" {
            persistMessageWindow()
        }
        ChatPaginationLogger.pageApplied(
            kind: kind,
            messageIds: messages.map(\.id),
            total: page.total,
            hasMoreOlder: hasMoreOlder,
            windowCount: messages.count
        )
    }

    @discardableResult
    private func loadOlderFromCacheIfPossible() -> Bool {
        guard let cached = messageCache.loadWindow(sessionId: session.id),
              let anchorId = messages.first?.id,
              let anchorIndex = cached.messages.firstIndex(where: { $0.id == anchorId }),
              anchorIndex > 0 else {
            return false
        }

        let older = Array(cached.messages[..<anchorIndex])
        messages = older + messages
        totalCount = cached.total
        hasMoreOlder = messages.first?.id != cached.messages.first?.id || cached.hasMoreOlder
        scrollIntent = .preserve(messageId: anchorId)
        ChatPaginationLogger.pageApplied(
            kind: "older-cache",
            messageIds: older.map(\.id),
            total: cached.total,
            hasMoreOlder: hasMoreOlder,
            windowCount: messages.count
        )
        return true
    }

    private func mergeOlderLoadedMessages(with fetched: [KBMessage]) -> [KBMessage] {
        let fetchedIds = Set(fetched.map(\.id))
        let olderLoaded = messages.filter { !fetchedIds.contains($0.id) }
        return olderLoaded + fetched
    }

    private func mergedMessagesForPersistence(_ inMemory: [KBMessage]) -> [KBMessage] {
        guard let cached = messageCache.loadWindow(sessionId: session.id) else {
            return inMemory
        }
        var byId = Dictionary(uniqueKeysWithValues: cached.messages.map { ($0.id, $0) })
        for message in inMemory {
            byId[message.id] = message
        }
        return byId.values.sorted { lhs, rhs in
            let left = lhs.createdAt ?? .distantPast
            let right = rhs.createdAt ?? .distantPast
            if left == right { return lhs.id < rhs.id }
            return left < right
        }
    }

    private func persistMessageWindow() {
        let merged = mergedMessagesForPersistence(messages)
        messages = merged
        messageCache.saveWindow(
            sessionId: session.id,
            page: KBMessagesPage(
                messages: merged,
                total: totalCount,
                hasMoreOlder: hasMoreOlder
            )
        )
    }

    private func clamp(_ list: [KBMessage], to limit: Int) -> [KBMessage] {
        guard list.count > limit else { return list }
        return Array(list.suffix(limit))
    }

    private func normalizedFetchLimit(_ raw: Int) -> Int {
        min(max(raw, Self.pageSize), Self.maxMessagePageLimit)
    }
}
