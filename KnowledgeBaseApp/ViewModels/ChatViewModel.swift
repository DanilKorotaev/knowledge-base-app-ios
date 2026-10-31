import Foundation

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

    private(set) var session: KBSession
    var messages: [KBMessage] = []
    var composerDraft = ChatComposerDraft()
    private(set) var useKnowledgeBase: Bool
    var isLoading = false
    var isLoadingOlder = false
    var isSending = false
    var isSendingUIEvent = false
    /// Preference: agent may offer Interactive UI; latest panel is interactive when true.
    var structuredUIPreferenceEnabled = StructuredUIPreference.isEnabled

    /// Latest assistant message with a structured UI document (for in-flight / interactivity).
    var activeStructuredUIMessageId: String? {
        messages.last { $0.role == .assistant && $0.structuredUI != nil }?.id
    }

    func toggleStructuredUIPreference() {
        structuredUIPreferenceEnabled.toggle()
        StructuredUIPreference.isEnabled = structuredUIPreferenceEnabled
    }

    /// Promotes a local draft session after `POST /api/sessions` (needs `private(set)` writes).
    func promoteLocalDraft(from oldId: String, to created: KBSession) {
        session = created
        useKnowledgeBase = created.useKnowledgeBase
        sessionKBModeStore.remove(sessionId: oldId)
        sessionKBModeStore.save(sessionId: created.id, useKnowledgeBase: useKnowledgeBase)

        if let loaded = composerDraftStore.load(sessionId: oldId) {
            _ = composerDraftStore.save(
                sessionId: created.id,
                draft: loaded.draft,
                pendingVoiceCaptures: loaded.pendingVoiceCaptures
            )
            // Keep the old folder until send succeeds/fails cleanup — in-memory URLs
            // from before promote still point into `oldId/files/`.
            if !deferredComposerDraftCleanupIds.contains(oldId) {
                deferredComposerDraftCleanupIds.append(oldId)
            }
        }

        if let remapped = composerDraftStore.load(sessionId: created.id) {
            composerDraft = remapped.draft
            pendingVoiceCaptures = remapped.pendingVoiceCaptures
            syncTranscribingVoiceFlag()
        }

        if let inFlight = inFlightReplyStore.load(sessionId: oldId) {
            inFlightReplyStore.save(
                InFlightReplyState(
                    sessionId: created.id,
                    startedAt: inFlight.startedAt,
                    partialText: inFlight.partialText
                )
            )
            inFlightReplyStore.clear(sessionId: oldId)
        }

        NotificationCenter.default.post(
            name: .kbSessionThreadDidChange,
            object: nil,
            userInfo: [KBNotificationUserInfoKey.sessionId: created.id]
        )
    }

    /// Persist KB mode for this chat (draft stays local until first send).
    func setUseKnowledgeBase(_ enabled: Bool) {
        guard useKnowledgeBase != enabled else { return }
        useKnowledgeBase = enabled
        session = KBSession(
            id: session.id,
            title: session.title,
            messageCount: session.messageCount,
            updatedAt: session.updatedAt,
            useKnowledgeBase: enabled
        )
        sessionKBModeStore.save(sessionId: session.id, useKnowledgeBase: enabled)
    }

    /// Rename via API (or local-only for drafts). Updates `session` title on success.
    func renameSession(to title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: 400,
                apiMessage: "Title cannot be empty"
            )
        }
        if session.isLocalDraft {
            applySessionTitle(trimmed)
            return
        }
        guard let sessionCreator else {
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: 400,
                apiMessage: "Cannot rename session: missing session client"
            )
        }
        let updated = try await sessionCreator.updateSession(id: session.id, title: trimmed)
        session = updated
        NotificationCenter.default.post(
            name: .kbSessionThreadDidChange,
            object: nil,
            userInfo: [KBNotificationUserInfoKey.sessionId: updated.id]
        )
    }

    func applySessionTitle(_ title: String) {
        session = KBSession(
            id: session.id,
            title: title,
            messageCount: session.messageCount,
            updatedAt: session.updatedAt,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    /// Creates a read-only public URL for the current (server) session.
    func createShareLink() async throws -> SessionShareLink {
        guard !session.isLocalDraft else {
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: 400,
                apiMessage: "Send a message before sharing this chat"
            )
        }
        guard let sessionCreator else {
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: 400,
                apiMessage: "Cannot share session: missing session client"
            )
        }
        return try await sessionCreator.createSessionShare(sessionId: session.id, ttlDays: nil)
    }
    var isTranscribingVoice = false
    var pendingVoiceCaptures: [PendingVoiceCapture] = []
    var errorMessage: String?
    /// Hard send failure / pipeline-error reply: Retry on bubble, composer stays empty.
    var pendingSendRetry: FailedSendRetry?
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
    /// Overridable in tests to avoid long background polls.
    var replyPollMaxAttempts = 150
    var replyPollIntervalNanoseconds: UInt64 = 2_000_000_000
    /// Last persisted message id before the current send (optimistic merge / hard-fail baseline).
    var preSendLastMessageId: String?
    /// True after SSE/JSON `user_message_acked` for the in-flight send.
    var userMessageAckedForCurrentSend = false

    let client: ChatAPIClientProtocol
    /// Required to promote a local draft on first send (`POST /api/sessions`).
    let sessionCreator: KnowledgeBaseAPIClientProtocol?
    private let messageCache: MessageCacheStoreProtocol
    let composerDraftStore: ComposerDraftStoreProtocol
    let sessionKBModeStore: SessionKBModeStoreProtocol
    let inFlightReplyStore: InFlightReplyStoreProtocol
    var composerDraftSaveTask: Task<Void, Never>?
    /// Serializes draft → server promotion so concurrent sends create one session.
    var sessionPromotionTask: Task<KBSession, Error>?
    /// Draft-store session folders kept alive until send finishes (promote copies media
    /// under the new id but in-flight upload URLs may still point at the old folder).
    var deferredComposerDraftCleanupIds: [String] = []

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
        sessionCreator: KnowledgeBaseAPIClientProtocol? = nil,
        messageCache: MessageCacheStoreProtocol = FileOfflineCacheStore.shared,
        composerDraftStore: ComposerDraftStoreProtocol = ComposerDraftStore.shared,
        sessionKBModeStore: SessionKBModeStoreProtocol = SessionKBModeStore.shared,
        inFlightReplyStore: InFlightReplyStoreProtocol = InFlightReplyStore.shared
    ) {
        self.session = session
        self.client = client
        self.sessionCreator = sessionCreator
        self.messageCache = messageCache
        self.composerDraftStore = composerDraftStore
        self.sessionKBModeStore = sessionKBModeStore
        self.inFlightReplyStore = inFlightReplyStore
        self.useKnowledgeBase = sessionKBModeStore.useKnowledgeBase(for: session)
        restoreComposerDraftIfNeeded()
        restoreInFlightReplyUIIfNeeded()
    }

    func load() async {
        if session.isLocalDraft {
            isLoading = false
            syncStatus = .idle
            messages = []
            totalCount = 0
            hasMoreOlder = false
            return
        }
        // Promote mid-send flips `session.id` and re-triggers `.task(id:)`. Skip the
        // empty-server refresh so we do not race the in-flight first message upload.
        if isSending {
            return
        }

        let loadStarted = CFAbsoluteTimeGetCurrent()
        if messages.isEmpty {
            isLoading = true
        }
        let cacheStarted = CFAbsoluteTimeGetCurrent()
        await bootstrapFromCacheIfNeeded()
        if !messages.isEmpty {
            let cacheMs = Int((CFAbsoluteTimeGetCurrent() - cacheStarted) * 1_000)
            ChatOpenLogger.cacheBootstrapFinished(
                sessionId: session.id,
                messageCount: messages.count,
                milliseconds: cacheMs
            )
        }
        restoreInFlightReplyUIIfNeeded()
        let hadCachedMessages = !messages.isEmpty
        if hadCachedMessages {
            isLoading = false
            syncStatus = .refreshing
        }
        errorMessage = nil
        scrollIntent = .none
        ChatPaginationLogger.initialLoadStarted(sessionId: session.id)
        defer { isLoading = false }
        await refreshFromNetwork(hadLocalData: hadCachedMessages, kind: "initial")
        let loadMs = Int((CFAbsoluteTimeGetCurrent() - loadStarted) * 1_000)
        ChatOpenLogger.networkLoadFinished(
            sessionId: session.id,
            messageCount: messages.count,
            milliseconds: loadMs
        )
        restoreInFlightReplyUIIfNeeded()
        await resumeAwaitingReplyIfNeeded(allowWhileSending: false)
    }

    /// Background refresh (pull-to-refresh, app became active).
    func refresh() async {
        guard !session.isLocalDraft else { return }
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
                errorMessage = L10n.string("network.no_connection")
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

    private func bootstrapFromCacheIfNeeded() async {
        guard messages.isEmpty else { return }
        let sessionId = session.id
        let cache = messageCache
        let cached = await Task.detached(priority: .userInitiated) {
            cache.loadWindow(sessionId: sessionId)
        }.value
        guard let cached, !cached.messages.isEmpty else { return }
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

    func applyStreamUpdate(_ update: AssistantReplyStreamUpdate) {
        assistantReplyPhase = update.phase
        cursorActivityLabel = update.activityLabel
        scrollIntent = .scrollToBottom
        let partial = update.phase.displayText
        if !partial.isEmpty {
            inFlightReplyStore.updatePartial(sessionId: session.id, text: partial)
        }
    }

    func beginInFlightReply() {
        inFlightReplyStore.save(
            InFlightReplyState(sessionId: session.id, startedAt: Date(), partialText: nil)
        )
    }

    /// Snapshot current streaming text before the process may be suspended.
    func persistInFlightReplySnapshot() {
        guard assistantReplyPhase.showsPlaceholder || looksAwaitingAssistantReply else { return }
        let partial = assistantReplyPhase.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        inFlightReplyStore.save(
            InFlightReplyState(
                sessionId: session.id,
                startedAt: inFlightReplyStore.load(sessionId: session.id)?.startedAt ?? Date(),
                partialText: partial.isEmpty ? nil : partial
            )
        )
    }

    func clearInFlightReply() {
        inFlightReplyStore.clear(sessionId: session.id)
    }

    private func restoreInFlightReplyUIIfNeeded() {
        guard let state = inFlightReplyStore.load(sessionId: session.id) else { return }
        if !messages.isEmpty, !looksAwaitingAssistantReply {
            clearInFlightReply()
            return
        }
        if let partial = state.partialText?.trimmingCharacters(in: .whitespacesAndNewlines), !partial.isEmpty {
            assistantReplyPhase = .streaming(text: partial)
        } else {
            assistantReplyPhase = .waiting
        }
        scrollIntent = .scrollToBottom
    }

    /// SSE drop while the server may still finish — keep waiting UI, poll, no error alert.
    @discardableResult
    func handleResumableStreamInterruption(
        _ error: Error,
        partialText: String
    ) async -> Bool {
        guard StreamInterruptionClassifier.isResumable(error) else { return false }
        errorMessage = nil
        let trimmed = partialText.trimmingCharacters(in: .whitespacesAndNewlines)
        inFlightReplyStore.save(
            InFlightReplyState(
                sessionId: session.id,
                startedAt: Date(),
                partialText: trimmed.isEmpty ? nil : trimmed
            )
        )
        assistantReplyPhase = trimmed.isEmpty ? .waiting : .streaming(text: trimmed)
        cursorActivityLabel = nil
        scrollIntent = .scrollToBottom
        // Poll in the background so `isSending` can clear and the composer stays usable.
        Task { await self.resumeAwaitingReplyIfNeeded(allowWhileSending: true) }
        return true
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
            if messages.last?.role == .assistant {
                clearInFlightReply()
                assistantReplyPhase = .idle
                cursorActivityLabel = nil
            } else if inFlightReplyStore.load(sessionId: session.id) != nil, looksAwaitingAssistantReply {
                restoreInFlightReplyUIIfNeeded()
            } else {
                assistantReplyPhase = .idle
            }
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
    /// - Parameter allowWhileSending: call from stream `catch` while `isSending` is still true.
    @discardableResult
    func resumeAwaitingReplyIfNeeded(allowWhileSending: Bool = false) async -> Bool {
        guard !session.isLocalDraft else { return false }
        if isPollingForReply { return false }
        if isSending, !allowWhileSending { return false }
        let hasMarker = inFlightReplyStore.load(sessionId: session.id) != nil
        guard looksAwaitingAssistantReply else {
            if hasMarker { clearInFlightReply() }
            return false
        }
        // Orphan last-user (pipeline died, marker expired): do not spin forever.
        guard hasMarker || isRecentAwaitingUserMessage else {
            assistantReplyPhase = .idle
            return false
        }

        isPollingForReply = true
        if !assistantReplyPhase.showsPlaceholder {
            restoreInFlightReplyUIIfNeeded()
            if !assistantReplyPhase.showsPlaceholder {
                assistantReplyPhase = .waiting
            }
        }
        defer { isPollingForReply = false }

        await pollUntilAssistantReply()
        return true
    }

    private var looksAwaitingAssistantReply: Bool {
        messages.last?.role == .user
    }

    /// Share Send may not write an in-flight marker; still poll briefly for a fresh last user message.
    private var isRecentAwaitingUserMessage: Bool {
        guard let last = messages.last, last.role == .user, let createdAt = last.createdAt else { return false }
        return Date().timeIntervalSince(createdAt) <= Self.orphanAwaitingGraceInterval
    }

    private static let orphanAwaitingGraceInterval: TimeInterval = 60 * 10

    private func pollUntilAssistantReply() async {
        let maxAttempts = max(1, replyPollMaxAttempts)
        let intervalNanoseconds = replyPollIntervalNanoseconds

        for attempt in 0..<maxAttempts {
            if attempt > 0, intervalNanoseconds > 0 {
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
                    clearInFlightReply()
                    clearSavedComposerDraft()
                    scrollIntent = .scrollToBottom
                    return
                }
            } catch {
                ChatPaginationLogger.loadFailed("pollReply", error: error.localizedDescription)
            }
        }
        // No assistant after a full poll cycle.
        // Keep in-flight only when we still have streamed partial (resume later within maxAge).
        // Otherwise clear — orphan user messages must not spin processing forever.
        cursorActivityLabel = nil
        let partial = inFlightReplyStore.load(sessionId: session.id)?.partialText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if looksAwaitingAssistantReply, let partial, !partial.isEmpty {
            assistantReplyPhase = .streaming(text: partial)
            return
        }
        clearInFlightReply()
        assistantReplyPhase = .idle
    }

    func clearError() {
        errorMessage = nil
    }

    func startStructuredUIFlow() async {
        await sendStructuredUIEvent(actionId: "start", componentId: "bootstrap", values: nil)
    }

    func dismissStructuredUIFlow() async {
        await sendStructuredUIEvent(actionId: "dismiss", componentId: "toolbar_dismiss", values: nil)
    }

    func sendStructuredUIEvent(
        actionId: String,
        componentId: String,
        values: [String: StructuredUIFormValue]? = nil
    ) async {
        guard !isSendingUIEvent else { return }
        isSendingUIEvent = true
        errorMessage = nil
        scrollIntent = .scrollToBottom
        defer { isSendingUIEvent = false }
        do {
            let response = try await Self.performUIEvent(
                client: client,
                sessionId: session.id,
                actionId: actionId,
                componentId: componentId,
                values: values
            )
            applyUIEventResponse(response, actionId: actionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func performUIEvent(
        client: ChatAPIClientProtocol,
        sessionId: String,
        actionId: String,
        componentId: String,
        values: [String: StructuredUIFormValue]?
    ) async throws -> KBUIEventResponse {
        let schemaVersion = KBStructuredUIDocument.supportedSchemaVersion
        if let stub = client as? StubChatAPIClient {
            return try await stub.sendUIEvent(
                sessionId: sessionId,
                actionId: actionId,
                componentId: componentId,
                clientSchemaVersion: schemaVersion,
                values: values
            )
        }
        if let remote = client as? URLSessionKnowledgeBaseAPIClient {
            return try await remote.sendUIEvent(
                sessionId: sessionId,
                actionId: actionId,
                componentId: componentId,
                clientSchemaVersion: schemaVersion,
                values: values
            )
        }
        return try await client.sendUIEvent(
            sessionId: sessionId,
            actionId: actionId,
            componentId: componentId,
            clientSchemaVersion: schemaVersion,
            values: values
        )
    }

    private func applyUIEventResponse(_ response: KBUIEventResponse, actionId: String) {
        let limit = normalizedFetchLimit(response.messages.count)
        let page = KBMessagesPage(
            messages: clamp(response.messages, to: limit),
            total: response.messages.count,
            hasMoreOlder: response.messages.count > limit
        )
        apply(page: page, requestedLimit: limit, kind: "uiEvent")
        scrollIntent = .scrollToBottom
        syncStatus = .upToDate(lastSyncedAt: Date())
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

    func reportError(_ message: String) {
        errorMessage = message
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
            reconcileAssistantReplyPhaseAfterServerSync()
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

    /// Server pages replace optimistic bubbles; once assistant is persisted, hide the SSE placeholder.
    private func reconcileAssistantReplyPhaseAfterServerSync() {
        guard messages.last?.role == .assistant else { return }
        clearInFlightReply()
        assistantReplyPhase = .idle
        cursorActivityLabel = nil
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
        let olderLoaded = messages.filter { message in
            if message.id.hasPrefix("kb-optimistic-") {
                return !serverAcknowledgesOptimistic(message, in: fetched)
            }
            return !fetchedIds.contains(message.id)
        }
        return olderLoaded + fetched
    }

    /// Drop optimistic only when the server page contains *this* send's user turn — not any historical user.
    private func serverAcknowledgesOptimistic(_ optimistic: KBMessage, in fetched: [KBMessage]) -> Bool {
        if let clientId = optimistic.clientMessageId,
           fetched.contains(where: { $0.role == .user && $0.clientMessageId == clientId }) {
            return true
        }
        if fetched.contains(where: { $0.id == optimistic.id }) {
            return true
        }
        let baseline = preSendLastMessageId
        return fetched.contains { message in
            guard message.role == .user else { return false }
            guard let baseline else {
                return message.content == optimistic.content
            }
            if let messageId = Int(message.id), let baselineId = Int(baseline) {
                return messageId > baselineId
            }
            return message.id != baseline
        }
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
