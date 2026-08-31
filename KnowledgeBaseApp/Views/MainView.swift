import SwiftUI

struct MainView: View {
    private enum RootTab: Hashable {
        case sessions
        case settings
    }

    private let apiClient: KnowledgeBaseAPIClientProtocol
    private let chatClient: ChatAPIClientProtocol
    private let filesClient: FilesAPIClientProtocol
    private let attachmentLoader: KBAttachmentLoaderProtocol?
    @Binding var deepLinkVoiceRecording: Bool
    @Binding var deepLinkSessionId: String?
    @State private var selectedTab: RootTab = .sessions
    @State private var sessions: [KBSession] = []
    @State private var searchResults: [KBSession]?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var sessionsSyncStatus: SyncStatus = .idle
    @State private var didLoadSessionsOnce = false
    @State private var voiceViewModel: VoiceRecordingViewModel
    @State private var voiceRouting = VoiceRoutingContext()
    @State private var showNewSession = false
    @State private var newSessionTitle = ""
    @State private var newSessionUseKnowledgeBase = true
    @State private var sessionPendingDelete: KBSession?
    @State private var sessionPendingRename: KBSession?
    @State private var renameTitle = ""
    @State private var showRenameSheet = false
    @State private var sessionPendingVoiceDefault: KBSession?
    @State private var selectedVoiceDefaultTTL: DefaultVoiceSessionTTL = .oneHour
    @State private var sessionActionError: String?
    @State private var navigationPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var pinnedStore = PinnedSessionsStore.shared
    @State private var debugQuickActions = DebugQuickActionsController.shared
    private let sessionCache: SessionCacheStoreProtocol
    @Environment(\.scenePhase) private var scenePhase

    init(
        apiClient: KnowledgeBaseAPIClientProtocol = MainView.makeSessionClient(),
        chatClient: ChatAPIClientProtocol = MainView.makeChatClient(),
        filesClient: FilesAPIClientProtocol = MainView.makeFilesClient(),
        attachmentLoader: KBAttachmentLoaderProtocol? = nil,
        sessionCache: SessionCacheStoreProtocol = FileOfflineCacheStore.shared,
        deepLinkVoiceRecording: Binding<Bool> = .constant(false),
        deepLinkSessionId: Binding<String?> = .constant(nil)
    ) {
        self.apiClient = apiClient
        self.chatClient = chatClient
        self.filesClient = filesClient
        self.sessionCache = sessionCache
        self.attachmentLoader = attachmentLoader ?? MainView.makeAttachmentLoader()
        self._deepLinkVoiceRecording = deepLinkVoiceRecording
        self._deepLinkSessionId = deepLinkSessionId
        _voiceViewModel = State(initialValue: VoiceRecordingViewModel(chatClient: chatClient))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                mainListWithDebugChrome
                    // Hide tab bar from the stack root as soon as path is non-empty so the
                    // bar animates away with the push (destination-only hide is too late).
                    .toolbar(navigationPath.isEmpty ? .automatic : .hidden, for: .tabBar)
                    .navigationDestination(for: KBSession.self) { session in
                        ChatView(
                            session: session,
                            chatClient: chatClient,
                            attachmentLoader: attachmentLoader
                        )
                        // Safety net if root toolbar hasn't applied yet.
                        .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem {
                Label("tab.chats", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(RootTab.sessions)

            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .toolbar(settingsPath.isEmpty ? .automatic : .hidden, for: .tabBar)
                    .navigationDestination(for: SettingsRoute.self) { route in
                        switch route {
                        case .offlineCache:
                            OfflineCacheManagementView()
                                .toolbar(.hidden, for: .tabBar)
                        }
                    }
            }
            .tabItem {
                Label("tab.settings", systemImage: "gearshape")
            }
            .tag(RootTab.settings)
        }
        .environment(voiceRouting)
        .environment(voiceViewModel)
        .onAppear {
            updateMainScreenDebugGesture(isOnMainList: selectedTab == .sessions && navigationPath.isEmpty)
        }
    }

    /// Split modifiers across helpers so the Swift type checker stays fast.
    private var mainListWithDebugChrome: some View {
        mainListWithVoiceChrome
            .onChange(of: navigationPath.count) { _, count in
                updateMainScreenDebugGesture(isOnMainList: count == 0)
            }
            .onChange(of: selectedTab) { _, tab in
                updateMainScreenDebugGesture(isOnMainList: tab == .sessions && navigationPath.isEmpty)
            }
            .onDisappear {
                // Keep gesture available from Settings; only disable when this whole tab stack is gone.
            }
    }

    private var mainListWithVoiceChrome: some View {
        mainListWithSessionChrome
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onAppear {
                configureMainListOnAppear()
            }
            .onChange(of: deepLinkVoiceRecording) { _, newValue in
                guard newValue else { return }
                Task { @MainActor in
                    await openVoiceTargetSessionFromDeepLink()
                    deepLinkVoiceRecording = false
                }
            }
            .onChange(of: deepLinkSessionId, initial: true) { _, newValue in
                openDeepLinkedSessionIfNeeded(newValue)
            }
            .sheet(item: $sessionPendingVoiceDefault) { session in
                DefaultVoiceSessionTTLSheet(
                    session: session,
                    selectedTTL: $selectedVoiceDefaultTTL,
                    onCancel: {
                        sessionPendingVoiceDefault = nil
                    },
                    onConfirm: {
                        voiceRouting.setDefaultVoiceSession(session, ttl: selectedVoiceDefaultTTL)
                        sessionPendingVoiceDefault = nil
                    }
                )
            }
            .sheet(isPresented: postRecordReviewPresented) {
                postRecordReviewSheet
            }
            .alert("main.recording_alert", isPresented: recordingErrorPresented) {
                Button("common.ok", role: .cancel) {
                    voiceViewModel.clearError()
                }
            } message: {
                Text(voiceViewModel.errorMessage ?? "")
            }
    }

    private var mainListWithSessionChrome: some View {
        mainListBase
            .sheet(isPresented: $showNewSession) {
                NewSessionSheet(
                    title: $newSessionTitle,
                    useKnowledgeBase: $newSessionUseKnowledgeBase,
                    onCancel: { showNewSession = false },
                    onCreate: { Task { await createSessionAndDismiss() } }
                )
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameSessionSheet(
                    title: $renameTitle,
                    sessionName: sessionPendingRename?.title ?? "",
                    onCancel: {
                        showRenameSheet = false
                        sessionPendingRename = nil
                    },
                    onSave: { Task { await saveRenameAndDismiss() } }
                )
            }
            .alert("main.delete_session_title", isPresented: deleteConfirmPresented) {
                Button("common.delete", role: .destructive) {
                    guard let session = sessionPendingDelete else { return }
                    Task { await deleteSessionConfirmed(session) }
                }
                Button("common.cancel", role: .cancel) {
                    sessionPendingDelete = nil
                }
            } message: {
                if let session = sessionPendingDelete {
                    Text(L10n.format("main.delete_session_message_format", session.title))
                }
            }
            .alert("main.session_alert", isPresented: sessionActionErrorPresented) {
                Button("common.ok", role: .cancel) {
                    sessionActionError = nil
                }
            } message: {
                Text(sessionActionError ?? "")
            }
            .searchable(text: $searchText, prompt: "main.search_prompt")
            .task {
                guard !didLoadSessionsOnce else { return }
                didLoadSessionsOnce = true
                await loadSessions(showFullScreenLoading: true)
            }
            .onChange(of: searchText) { _, newValue in
                Task { await runSearch(query: newValue) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kbSessionThreadDidChange)) { _ in
                Task { await loadSessions(showFullScreenLoading: false) }
            }
    }

    private var mainListBase: some View {
        mainStackContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("main.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await loadSessions(showFullScreenLoading: false) }
                    } label: {
                        Label("common.refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSessionTitle = ""
                        showNewSession = true
                    } label: {
                        Label("main.new_session", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChangedFilesView(filesClient: filesClient)
                    } label: {
                        Label("main.changed_files", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
    }

    private var sessionActionErrorPresented: Binding<Bool> {
        Binding(
            get: { sessionActionError != nil },
            set: { if !$0 { sessionActionError = nil } }
        )
    }

    private var postRecordReviewPresented: Binding<Bool> {
        Binding(
            get: { voiceViewModel.showPostRecordReview },
            set: { newValue in
                if !newValue {
                    voiceViewModel.dismissPostRecordReview()
                }
            }
        )
    }

    private var recordingErrorPresented: Binding<Bool> {
        Binding(
            get: { voiceViewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    voiceViewModel.clearError()
                }
            }
        )
    }

    private var postRecordReviewSheet: some View {
        PostRecordingReviewSheet(
            viewModel: voiceViewModel,
            sessions: sessions,
            voiceRouting: voiceRouting
        )
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        voiceViewModel.handleScenePhaseChange(newPhase)
        guard newPhase == .active else { return }
        voiceRouting.refreshExpiryIfNeeded()
        Task { await loadSessions(showFullScreenLoading: false) }
    }

    private func configureMainListOnAppear() {
        // Voice recording lives in Chat composer and Apple Watch — not on the session list.
        voiceViewModel.recordingFinishedOutsideChatHandler = nil
        updateMainScreenDebugGesture(isOnMainList: navigationPath.isEmpty)
    }

    private func openDeepLinkedSessionIfNeeded(_ sessionId: String?) {
        guard let sessionId else { return }
        selectedTab = .sessions
        Task { @MainActor in
            await openSessionFromDeepLink(sessionId: sessionId)
            deepLinkSessionId = nil
        }
    }

    private func updateMainScreenDebugGesture(isOnMainList: Bool) {
        // Available on the session list and on Settings (not inside an open chat).
        let enabled = selectedTab == .settings || isOnMainList
        ThreeFingerSwipeDownInstaller.shared.setEnabled(enabled) {
            debugQuickActions.presentDebugMenuFromMainGesture()
        }
    }

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var deleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { sessionPendingDelete != nil },
            set: { if !$0 { sessionPendingDelete = nil } }
        )
    }

    @ViewBuilder
    private var mainStackContent: some View {
        if isLoading {
            ProgressView("main.loading_sessions")
        } else if let loadError {
            ContentUnavailableView(
                "main.could_not_load",
                systemImage: "exclamationmark.triangle",
                description: Text(loadError)
            )
        } else if displayedSessions.isEmpty {
            ContentUnavailableView(
                isSearchActive ? "main.no_matches" : "main.no_sessions",
                systemImage: isSearchActive ? "magnifyingglass" : "bubble.left.and.bubble.right",
                description: Text(
                    isSearchActive
                        ? "main.no_matches_hint"
                        : "main.no_sessions_hint"
                )
            )
        } else {
            sessionsList
        }
    }

    private var sessionsList: some View {
        List {
            if sessionsSyncStatus.showsBanner {
                SyncStatusBannerView(status: sessionsSyncStatus)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if let notice = voiceRouting.defaultExpiredNotice {
                VoiceDefaultExpiredBanner(notice: notice) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        voiceRouting.dismissDefaultExpiredNotice()
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            ForEach(displayedSessions) { session in
                sessionRow(session)
            }
        }
        .refreshable {
            await loadSessions(showFullScreenLoading: false)
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: KBSession) -> some View {
        NavigationLink(value: session) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.title)
                        .font(.headline)
                    if pinnedStore.isPinned(session.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("main.pinned_a11y"))
                    }
                    if voiceRouting.isDefaultVoiceSession(session.id) {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("main.default_for_voice_a11y"))
                    }
                }
                Text(L10n.format("main.messages_count_format", session.messageCount, session.kbModeSubtitle()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if voiceRouting.isDefaultVoiceSession(session.id) {
                Button {
                    voiceRouting.clearDefaultVoiceSession()
                } label: {
                    Label("main.clear_default", systemImage: "mic.slash")
                }
                .tint(.gray)
            } else {
                Button {
                    beginSetVoiceDefault(session)
                } label: {
                    Label("main.voice_default", systemImage: "mic")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if pinnedStore.isPinned(session.id) {
                Button {
                    unpinSession(session)
                } label: {
                    Label("common.unpin", systemImage: "pin.slash")
                }
                .tint(.orange)
            } else {
                Button {
                    pinSession(session)
                } label: {
                    Label("common.pin", systemImage: "pin")
                }
                .tint(.indigo)
            }
            Button(role: .destructive) {
                sessionPendingDelete = session
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
        .contextMenu {
            if pinnedStore.isPinned(session.id) {
                Button {
                    unpinSession(session)
                } label: {
                    Label("common.unpin", systemImage: "pin.slash")
                }
            } else {
                Button {
                    pinSession(session)
                } label: {
                    Label("common.pin", systemImage: "pin")
                }
            }
            if voiceRouting.isDefaultVoiceSession(session.id) {
                Button {
                    voiceRouting.clearDefaultVoiceSession()
                } label: {
                    Label("main.clear_voice_default", systemImage: "mic.slash")
                }
            } else {
                Button {
                    beginSetVoiceDefault(session)
                } label: {
                    Label("main.set_voice_default", systemImage: "mic")
                }
            }
            Button {
                beginRename(session)
            } label: {
                Label("common.rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                sessionPendingDelete = session
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private var displayedSessions: [KBSession] {
        if isSearchActive {
            return searchResults ?? []
        }
        return sessions
    }

    @MainActor
    private func runSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = nil
            isSearching = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await apiClient.searchSessions(query: trimmed)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    private func loadSessions(showFullScreenLoading: Bool) async {
        if sessions.isEmpty, let cached = sessionCache.loadSessions(), !cached.isEmpty {
            sessions = applyPinnedOrder(to: cached)
        }

        let hasLocalData = !sessions.isEmpty
        if hasLocalData {
            sessionsSyncStatus = .refreshing
        } else if showFullScreenLoading {
            isLoading = true
        }

        loadError = nil
        let showBlockingLoader = showFullScreenLoading && !hasLocalData
        defer {
            if showBlockingLoader {
                isLoading = false
            }
        }

        guard NetworkPathMonitor.shared.isOnline else {
            if hasLocalData {
                sessionsSyncStatus = .offline(lastSyncedAt: sessionCache.lastSessionsSyncAt())
            } else {
                loadError = L10n.string("network.no_connection")
                sessionsSyncStatus = .offline(lastSyncedAt: nil)
            }
            return
        }

        do {
            let fetched = try await apiClient.fetchSessions()
            pinnedStore.prune(validSessionIds: Set(fetched.map(\.id)))
            SessionKBModeStore.shared.prune(validSessionIds: Set(fetched.map(\.id)))
            sessions = applyPinnedOrder(to: fetched)
            sessionCache.saveSessions(fetched)
            voiceRouting.refreshExpiryIfNeeded()
            sessionsSyncStatus = .upToDate(lastSyncedAt: Date())
        } catch {
            let lastSynced = sessionCache.lastSessionsSyncAt()
            if hasLocalData {
                sessionsSyncStatus = SyncNetworkError.failureStatus(
                    error: error,
                    lastSyncedAt: lastSynced,
                    isPathOnline: NetworkPathMonitor.shared.isOnline
                )
            } else {
                loadError = error.localizedDescription
                sessionsSyncStatus = SyncNetworkError.failureStatus(
                    error: error,
                    lastSyncedAt: nil,
                    isPathOnline: NetworkPathMonitor.shared.isOnline
                )
            }
        }
    }

    @MainActor
    private func applyPinnedOrder(to fetched: [KBSession]) -> [KBSession] {
        SessionListSorter.displayOrder(
            sessions: fetched,
            pinnedIds: pinnedStore.loadOrderedIds()
        )
    }

    @MainActor
    private func pinSession(_ session: KBSession) {
        pinnedStore.pin(sessionId: session.id)
        sessions = applyPinnedOrder(to: sessions)
    }

    @MainActor
    private func unpinSession(_ session: KBSession) {
        pinnedStore.unpin(sessionId: session.id)
        sessions = applyPinnedOrder(to: sessions)
    }

    @MainActor
    private func createSessionAndDismiss() async {
        do {
            let useKB = newSessionUseKnowledgeBase
            let created = try await apiClient.createSession(
                title: newSessionTitle,
                useKnowledgeBase: useKB
            )
            SessionKBModeStore.shared.save(sessionId: created.id, useKnowledgeBase: useKB)
            newSessionTitle = ""
            newSessionUseKnowledgeBase = true
            showNewSession = false
            await loadSessions(showFullScreenLoading: false)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    private func openSessionFromDeepLink(sessionId: String) async {
        selectedTab = .sessions
        if let existing = sessions.first(where: { $0.id == sessionId }) {
            navigationPath = NavigationPath()
            navigationPath.append(existing)
            return
        }
        await loadSessions(showFullScreenLoading: false)
        if let found = sessions.first(where: { $0.id == sessionId }) {
            navigationPath = NavigationPath()
            navigationPath.append(found)
            return
        }
        if let found = searchResults?.first(where: { $0.id == sessionId }) {
            navigationPath = NavigationPath()
            navigationPath.append(found)
        }
    }

    /// Widget / Watch `knowledgebase://record`: open the voice-default (or newest) chat so recording happens in composer.
    @MainActor
    private func openVoiceTargetSessionFromDeepLink() async {
        selectedTab = .sessions
        if sessions.isEmpty {
            await loadSessions(showFullScreenLoading: false)
        }
        guard let session = voiceRouting.resolveVoiceTargetSession(in: sessions) ?? sessions.first else {
            return
        }
        navigationPath = NavigationPath()
        navigationPath.append(session)
    }

    @MainActor
    private func beginSetVoiceDefault(_ session: KBSession) {
        selectedVoiceDefaultTTL = .oneHour
        sessionPendingVoiceDefault = session
    }

    @MainActor
    private func beginRename(_ session: KBSession) {
        sessionPendingRename = session
        renameTitle = session.title
        showRenameSheet = true
    }

    @MainActor
    private func saveRenameAndDismiss() async {
        guard let session = sessionPendingRename else { return }
        let trimmed = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        showRenameSheet = false
        sessionPendingRename = nil

        do {
            _ = try await apiClient.updateSession(id: session.id, title: trimmed)
            renameTitle = ""
            if isSearchActive {
                await runSearch(query: searchText)
            } else {
                await loadSessions(showFullScreenLoading: false)
            }
        } catch {
            sessionActionError = error.localizedDescription
        }
    }

    @MainActor
    private func deleteSessionConfirmed(_ session: KBSession) async {
        sessionPendingDelete = nil

        voiceRouting.handleDeletedSession(session.id)
        pinnedStore.remove(sessionId: session.id)
        SessionKBModeStore.shared.remove(sessionId: session.id)
        sessionCache.removeSession(id: session.id)

        let previousSessions = sessions
        let previousSearch = searchResults

        if isSearchActive {
            searchResults?.removeAll { $0.id == session.id }
        } else {
            sessions.removeAll { $0.id == session.id }
        }

        do {
            try await apiClient.deleteSession(id: session.id)
            if isSearchActive {
                await runSearch(query: searchText)
            } else {
                await loadSessions(showFullScreenLoading: false)
            }
        } catch {
            sessions = previousSessions
            searchResults = previousSearch
            sessionActionError = error.localizedDescription
        }
    }

    /// Shared with `StubChatAPIClient` so demo session messages stay in sync without a server.
    private static let stubStore = InMemoryKBStore()

    private static func remoteBundle() -> URLSessionKnowledgeBaseAPIClient? {
        URLSessionKnowledgeBaseAPIClient()
    }

    private static func makeSessionClient() -> KnowledgeBaseAPIClientProtocol {
        if let remote = remoteBundle() {
            return remote
        }
        return StubKnowledgeBaseAPIClient(store: stubStore)
    }

    private static func makeChatClient() -> ChatAPIClientProtocol {
        if let remote = remoteBundle() {
            return remote
        }
        return StubChatAPIClient(store: stubStore)
    }

    private static func makeFilesClient() -> FilesAPIClientProtocol {
        if let remote = remoteBundle() {
            return remote
        }
        return StubFilesAPIClient()
    }

    private static func makeAttachmentLoader() -> KBAttachmentLoaderProtocol? {
        let inner: KBAttachmentLoaderProtocol = remoteBundle() ?? StubAttachmentLoader()
        return CachingAttachmentLoader(inner: inner, cache: FileAttachmentDiskCache.shared)
    }
}

#Preview {
    MainView(
        apiClient: StubKnowledgeBaseAPIClient(store: InMemoryKBStore()),
        chatClient: StubChatAPIClient(store: InMemoryKBStore()),
        filesClient: StubFilesAPIClient(),
        deepLinkVoiceRecording: .constant(false),
        deepLinkSessionId: .constant(nil)
    )
}
