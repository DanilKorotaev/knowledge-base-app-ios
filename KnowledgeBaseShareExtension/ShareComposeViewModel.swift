import Foundation
import Observation

@MainActor
@Observable
final class ShareComposeViewModel {
    enum Phase: Equatable {
        case loadingPayload
        case ready
        case working
        case failed(String)
    }

    private(set) var phase: Phase = .loadingPayload
    private(set) var sessions: [KBSession] = []
    var selectedSessionId: String?
    var composerText: String = ""
    private(set) var attachments: [PendingAttachment] = []
    /// Attachments already stored in the session draft (shown for context when sending).
    private(set) var existingDraftAttachmentCount = 0
    var showCreateSession = false
    var newSessionTitle = ""
    var newSessionUseKnowledgeBase = true

    private let draftStore: ComposerDraftStoreProtocol
    private let apiClient: ShareAPIClient?
    private var pinnedIds: [String] = []
    private var kbModeBySession: [String: Bool] = [:]

    init(
        draftStore: ComposerDraftStoreProtocol = ComposerDraftStore.shared,
        apiClient: ShareAPIClient? = ShareAPIClient()
    ) {
        self.draftStore = draftStore
        self.apiClient = apiClient
    }

    var canSubmit: Bool {
        guard let sessionId = selectedSessionId else { return false }
        return buildOutgoingDraft(sessionId: sessionId).canSend
    }

    var selectedSessionTitle: String {
        sessions.first(where: { $0.id == selectedSessionId })?.title ?? ""
    }

    func isPinned(_ sessionId: String) -> Bool {
        pinnedIds.contains(sessionId)
    }

    func bootstrap(extensionContext: NSExtensionContext?) async {
        phase = .loadingPayload
        loadSharedPrefs()
        ShareFileLogger.info("bootstrap start")

        async let payloadTask = ShareItemLoader.load(from: extensionContext)
        async let sessionsTask: [KBSession] = {
            guard let apiClient else { return [] }
            return (try? await apiClient.fetchSessions()) ?? []
        }()

        let payload = await payloadTask
        let fetched = await sessionsTask

        composerText = payload.text
        attachments = payload.attachments
        sessions = SessionListSorter.displayOrder(sessions: fetched, pinnedIds: pinnedIds)
        ShareFileLogger.info(
            "bootstrap payload textLen=\(payload.text.count) attachments=\(payload.attachments.count) sessions=\(sessions.count)"
        )

        if apiClient == nil {
            phase = .failed(L10n.string("share.error_missing_config"))
            ShareFileLogger.error("bootstrap missing API config")
        } else {
            phase = .ready
        }
    }

    func selectSession(_ session: KBSession) {
        selectedSessionId = session.id
        refreshExistingDraftSummary(for: session.id)
        ShareFileLogger.info(
            "selectSession id=\(session.id) existingDraftAttachments=\(existingDraftAttachmentCount)"
        )
    }

    func createSession() async {
        guard let apiClient else {
            phase = .failed(L10n.string("share.error_missing_config"))
            return
        }
        let title = newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        phase = .working
        do {
            let created = try await apiClient.createSession(
                title: title,
                useKnowledgeBase: newSessionUseKnowledgeBase
            )
            persistKBMode(sessionId: created.id, useKnowledgeBase: newSessionUseKnowledgeBase)
            sessions = SessionListSorter.displayOrder(
                sessions: [created] + sessions.filter { $0.id != created.id },
                pinnedIds: pinnedIds
            )
            selectedSessionId = created.id
            existingDraftAttachmentCount = 0
            newSessionTitle = ""
            newSessionUseKnowledgeBase = true
            showCreateSession = false
            phase = .ready
            ShareFileLogger.info("createSession ok id=\(created.id)")
        } catch {
            ShareFileLogger.error("createSession failed: \(error)")
            phase = .failed(L10n.string("share.error_create_session"))
        }
    }

    func addToDraft() -> Bool {
        guard let sessionId = selectedSessionId else { return false }
        phase = .working
        ShareFileLogger.info(
            "addToDraft session=\(sessionId) textLen=\(composerText.count) attachments=\(attachments.count)"
        )
        let result = draftStore.merge(
            sessionId: sessionId,
            text: composerText,
            attachments: attachments
        )
        if result == nil && composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty {
            phase = .ready
            return false
        }
        if result == nil {
            ShareFileLogger.error("addToDraft save failed")
            phase = .failed(L10n.string("share.error_save_draft"))
            return false
        }
        ShareFileLogger.info("addToDraft ok attachments=\(result?.draft.attachments.count ?? 0)")
        return true
    }

    func send() async -> Bool {
        guard let sessionId = selectedSessionId, let apiClient else {
            phase = .failed(L10n.string("share.error_missing_config"))
            return false
        }

        let existingPending = draftStore.load(sessionId: sessionId)?.pendingVoiceCaptures ?? []
        let outgoing = buildOutgoingDraft(sessionId: sessionId)
        guard outgoing.canSend else { return false }

        phase = .working
        let useKB = kbModeBySession[sessionId]
            ?? sessions.first(where: { $0.id == sessionId })?.useKnowledgeBase
            ?? true

        ShareFileLogger.info(
            "send merge session=\(sessionId) outgoingTextLen=\(outgoing.text.count) outgoingAttachments=\(outgoing.attachments.count)"
        )

        do {
            try await apiClient.sendComposed(
                sessionId: sessionId,
                draft: outgoing,
                useKnowledgeBase: useKB
            )
            draftStore.clear(sessionId: sessionId)
            existingDraftAttachmentCount = 0
            ShareFileLogger.info("send accepted and draft cleared session=\(sessionId)")
            return true
        } catch {
            ShareFileLogger.error("send failed: \(error) — persisting merged draft")
            _ = draftStore.save(
                sessionId: sessionId,
                draft: outgoing,
                pendingVoiceCaptures: existingPending
            )
            refreshExistingDraftSummary(for: sessionId)
            phase = .failed(L10n.string("share.error_send_saved_draft"))
            return false
        }
    }

    /// Current share payload merged on top of any existing session draft (append, do not replace).
    func buildOutgoingDraft(sessionId: String) -> ChatComposerDraft {
        let existing = draftStore.load(sessionId: sessionId)?.draft ?? ChatComposerDraft()
        return ComposerDraftMerger.merge(
            existing: existing,
            text: composerText,
            attachments: attachments
        )
    }

    private func refreshExistingDraftSummary(for sessionId: String) {
        let loaded = draftStore.load(sessionId: sessionId)
        existingDraftAttachmentCount = loaded?.draft.attachments.count ?? 0
    }

    private func loadSharedPrefs() {
        let suite = AppGroupContainer.sharedDefaults
        if let data = suite?.data(forKey: "kb.sessions.pinned_ids") {
            pinnedIds = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        if let data = suite?.data(forKey: "kb.sessions.use_knowledge_base") {
            kbModeBySession = (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
        }
    }

    private func persistKBMode(sessionId: String, useKnowledgeBase: Bool) {
        kbModeBySession[sessionId] = useKnowledgeBase
        guard let suite = AppGroupContainer.sharedDefaults else { return }
        var map = kbModeBySession
        if let data = suite.data(forKey: "kb.sessions.use_knowledge_base"),
           let existing = try? JSONDecoder().decode([String: Bool].self, from: data) {
            map = existing
            map[sessionId] = useKnowledgeBase
        }
        if let data = try? JSONEncoder().encode(map) {
            suite.set(data, forKey: "kb.sessions.use_knowledge_base")
        }
        kbModeBySession = map
    }
}
