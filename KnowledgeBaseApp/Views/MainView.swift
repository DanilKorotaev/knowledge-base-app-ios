import SwiftUI

struct MainView: View {
    private let apiClient: KnowledgeBaseAPIClientProtocol
    private let chatClient: ChatAPIClientProtocol
    private let filesClient: FilesAPIClientProtocol
    private let attachmentLoader: KBAttachmentLoaderProtocol?
    @Binding var deepLinkVoiceRecording: Bool
    @Binding var deepLinkSessionId: String?
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
    @State private var sessionPendingDelete: KBSession?
    @State private var sessionPendingRename: KBSession?
    @State private var renameTitle = ""
    @State private var showRenameSheet = false
    @State private var sessionPendingVoiceDefault: KBSession?
    @State private var selectedVoiceDefaultTTL: DefaultVoiceSessionTTL = .oneHour
    @State private var sessionActionError: String?
    @State private var navigationPath = NavigationPath()
    @State private var pinnedStore = PinnedSessionsStore.shared
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
        NavigationStack(path: $navigationPath) {
            mainStackContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Knowledge Base")
            .safeAreaInset(edge: .top, spacing: 0) {
                if deepLinkVoiceRecording {
                    Text("Tap the microphone below to start a voice request.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.38))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await loadSessions(showFullScreenLoading: false) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSessionTitle = ""
                        showNewSession = true
                    } label: {
                        Label("New session", systemImage: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChangedFilesView(filesClient: filesClient)
                    } label: {
                        Label("Changed files", systemImage: "doc.text.magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showNewSession) {
                NewSessionSheet(
                    title: $newSessionTitle,
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
            .alert("Delete session?", isPresented: deleteConfirmPresented) {
                Button("Delete", role: .destructive) {
                    guard let session = sessionPendingDelete else { return }
                    Task { await deleteSessionConfirmed(session) }
                }
                Button("Cancel", role: .cancel) {
                    sessionPendingDelete = nil
                }
            } message: {
                if let session = sessionPendingDelete {
                    Text("“\(session.title)” will be removed from your list. This cannot be undone from the app.")
                }
            }
            .alert(
                "Session",
                isPresented: Binding(
                    get: { sessionActionError != nil },
                    set: { if !$0 { sessionActionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    sessionActionError = nil
                }
            } message: {
                Text(sessionActionError ?? "")
            }
            .searchable(text: $searchText, prompt: "ID or message text")
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    voiceRouting.refreshExpiryIfNeeded()
                    Task { await loadSessions(showFullScreenLoading: false) }
                }
            }
            .onAppear {
                voiceViewModel.recordingFinishedOutsideChatHandler = { url in
                    routeMainScreenVoiceToDefaultChat(audioURL: url)
                }
            }
            .onChange(of: deepLinkVoiceRecording) { _, newValue in
                guard newValue else { return }
                Task {
                    try? await Task.sleep(for: .seconds(12))
                    await MainActor.run {
                        deepLinkVoiceRecording = false
                    }
                }
            }
            .onChange(of: deepLinkSessionId, initial: true) { _, newValue in
                guard let sessionId = newValue else { return }
                Task {
                    await openSessionFromDeepLink(sessionId: sessionId)
                    await MainActor.run {
                        deepLinkSessionId = nil
                    }
                }
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
            .sheet(isPresented: Binding(
                get: { voiceViewModel.showPostRecordReview },
                set: { newValue in
                    if !newValue {
                        voiceViewModel.dismissPostRecordReview()
                    }
                }
            )) {
                @Bindable var voice = voiceViewModel
                @Bindable var routing = voiceRouting
                PostRecordingReviewSheet(
                    viewModel: voice,
                    sessions: sessions,
                    voiceRouting: routing
                )
            }
            .alert("Recording", isPresented: Binding(
                get: { voiceViewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        voiceViewModel.clearError()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    voiceViewModel.clearError()
                }
            } message: {
                Text(voiceViewModel.errorMessage ?? "")
            }
            .navigationDestination(for: KBSession.self) { session in
                ChatView(
                    session: session,
                    chatClient: chatClient,
                    attachmentLoader: attachmentLoader
                )
            }
        }
        .environment(voiceRouting)
        .environment(voiceViewModel)
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
            ProgressView("Loading sessions…")
        } else if let loadError {
            ContentUnavailableView(
                "Could not load",
                systemImage: "exclamationmark.triangle",
                description: Text(loadError)
            )
        } else if displayedSessions.isEmpty {
            ContentUnavailableView(
                isSearchActive ? "No matches" : "No sessions",
                systemImage: isSearchActive ? "magnifyingglass" : "bubble.left.and.bubble.right",
                description: Text(
                    isSearchActive
                        ? "Try another query (session ID or text from messages)."
                        : "Configure the API in Settings, or use a stub build with a demo session when no server is set."
                )
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MicBar(viewModel: voiceViewModel, voiceRouting: voiceRouting)
            }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MicBar(viewModel: voiceViewModel, voiceRouting: voiceRouting)
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
                            .accessibilityLabel("Pinned")
                    }
                    if voiceRouting.isDefaultVoiceSession(session.id) {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Default for voice")
                    }
                }
                Text("\(session.messageCount) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if voiceRouting.isDefaultVoiceSession(session.id) {
                Button {
                    voiceRouting.clearDefaultVoiceSession()
                } label: {
                    Label("Clear default", systemImage: "mic.slash")
                }
                .tint(.gray)
            } else {
                Button {
                    beginSetVoiceDefault(session)
                } label: {
                    Label("Voice default", systemImage: "mic")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if pinnedStore.isPinned(session.id) {
                Button {
                    unpinSession(session)
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }
                .tint(.orange)
            } else {
                Button {
                    pinSession(session)
                } label: {
                    Label("Pin", systemImage: "pin")
                }
                .tint(.indigo)
            }
            Button(role: .destructive) {
                sessionPendingDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            if pinnedStore.isPinned(session.id) {
                Button {
                    unpinSession(session)
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }
            } else {
                Button {
                    pinSession(session)
                } label: {
                    Label("Pin", systemImage: "pin")
                }
            }
            if voiceRouting.isDefaultVoiceSession(session.id) {
                Button {
                    voiceRouting.clearDefaultVoiceSession()
                } label: {
                    Label("Clear voice default", systemImage: "mic.slash")
                }
            } else {
                Button {
                    beginSetVoiceDefault(session)
                } label: {
                    Label("Set as voice default", systemImage: "mic")
                }
            }
            Button {
                beginRename(session)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                sessionPendingDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
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
                loadError = "Нет подключения к сети"
                sessionsSyncStatus = .offline(lastSyncedAt: nil)
            }
            return
        }

        do {
            let fetched = try await apiClient.fetchSessions()
            pinnedStore.prune(validSessionIds: Set(fetched.map(\.id)))
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
            _ = try await apiClient.createSession(title: newSessionTitle)
            newSessionTitle = ""
            showNewSession = false
            await loadSessions(showFullScreenLoading: false)
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    private func openSessionFromDeepLink(sessionId: String) async {
        if let existing = sessions.first(where: { $0.id == sessionId }) {
            navigationPath.append(existing)
            return
        }
        await loadSessions(showFullScreenLoading: false)
        if let found = sessions.first(where: { $0.id == sessionId }) {
            navigationPath.append(found)
            return
        }
        if let found = searchResults?.first(where: { $0.id == sessionId }) {
            navigationPath.append(found)
        }
    }

    @MainActor
    private func routeMainScreenVoiceToDefaultChat(audioURL: URL) -> Bool {
        guard let session = voiceRouting.mainScreenVoiceChatSession(in: sessions) else {
            return false
        }
        voiceRouting.pendingComposerVoice = (sessionId: session.id, audioURL: audioURL)
        navigationPath.append(session)
        return true
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

private struct MicBar: View {
    @Bindable var viewModel: VoiceRecordingViewModel
    @Bindable var voiceRouting: VoiceRoutingContext

    /// В режиме записи панель тянется на всю ширину; в idle — небольшие боковые отступы у микрофона.
    private var horizontalPadding: CGFloat {
        viewModel.phase == .idle ? 16 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            VoiceDefaultSessionIndicator(label: voiceRouting.indicatorLabel())
            MicRecordControl(viewModel: viewModel)
                .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
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
