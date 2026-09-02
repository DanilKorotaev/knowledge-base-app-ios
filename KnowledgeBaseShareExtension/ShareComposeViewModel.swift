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
        guard selectedSessionId != nil else { return false }
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || !attachments.isEmpty
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

        if apiClient == nil {
            phase = .failed(L10n.string("share.error_missing_config"))
        } else if sessions.isEmpty && fetched.isEmpty {
            phase = .ready
        } else {
            phase = .ready
        }
    }

    func selectSession(_ session: KBSession) {
        selectedSessionId = session.id
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
            newSessionTitle = ""
            newSessionUseKnowledgeBase = true
            showCreateSession = false
            phase = .ready
        } catch {
            phase = .failed(L10n.string("share.error_create_session"))
        }
    }

    func addToDraft() -> Bool {
        guard let sessionId = selectedSessionId else { return false }
        phase = .working
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
            phase = .failed(L10n.string("share.error_save_draft"))
            return false
        }
        return true
    }

    func send() async -> Bool {
        guard let sessionId = selectedSessionId, let apiClient else {
            phase = .failed(L10n.string("share.error_missing_config"))
            return false
        }

        var draft = ChatComposerDraft()
        draft.text = composerText
        draft.attachments = attachments
        guard draft.canSend else { return false }

        phase = .working
        let useKB = kbModeBySession[sessionId]
            ?? sessions.first(where: { $0.id == sessionId })?.useKnowledgeBase
            ?? true

        do {
            try await apiClient.sendComposed(
                sessionId: sessionId,
                draft: draft,
                useKnowledgeBase: useKB
            )
            return true
        } catch {
            _ = draftStore.merge(
                sessionId: sessionId,
                text: composerText,
                attachments: attachments
            )
            phase = .failed(L10n.string("share.error_send_saved_draft"))
            return false
        }
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
