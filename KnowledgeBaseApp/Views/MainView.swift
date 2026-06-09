import SwiftUI

struct MainView: View {
    private let apiClient: KnowledgeBaseAPIClientProtocol
    private let chatClient: ChatAPIClientProtocol
    private let filesClient: FilesAPIClientProtocol
    private let attachmentLoader: KBAttachmentLoaderProtocol?
    @Binding var deepLinkVoiceRecording: Bool
    @State private var sessions: [KBSession] = []
    @State private var searchResults: [KBSession]?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var loadError: String?
    @State private var isLoading = false
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
    @State private var showVoiceDefaultTTLSheet = false
    @State private var selectedVoiceDefaultTTL: DefaultVoiceSessionTTL = .oneHour
    @State private var sessionActionError: String?
    @State private var navigationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    init(
        apiClient: KnowledgeBaseAPIClientProtocol = MainView.makeSessionClient(),
        chatClient: ChatAPIClientProtocol = MainView.makeChatClient(),
        filesClient: FilesAPIClientProtocol = MainView.makeFilesClient(),
        attachmentLoader: KBAttachmentLoaderProtocol? = nil,
        deepLinkVoiceRecording: Binding<Bool> = .constant(false)
    ) {
        self.apiClient = apiClient
        self.chatClient = chatClient
        self.filesClient = filesClient
        self.attachmentLoader = attachmentLoader ?? MainView.makeAttachmentLoader()
        self._deepLinkVoiceRecording = deepLinkVoiceRecording
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
                } else if let notice = voiceRouting.defaultExpiredNotice {
                    Text(notice)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.orange.opacity(0.28))
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
            .sheet(isPresented: $showVoiceDefaultTTLSheet) {
                if let session = sessionPendingVoiceDefault {
                    DefaultVoiceSessionTTLSheet(
                        session: session,
                        selectedTTL: $selectedVoiceDefaultTTL,
                        onCancel: {
                            showVoiceDefaultTTLSheet = false
                            sessionPendingVoiceDefault = nil
                        },
                        onConfirm: {
                            voiceRouting.setDefaultVoiceSession(session, ttl: selectedVoiceDefaultTTL)
                            showVoiceDefaultTTLSheet = false
                            sessionPendingVoiceDefault = nil
                        }
                    )
                }
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
        List(displayedSessions) { session in
            sessionRow(session)
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
            Button(role: .destructive) {
                sessionPendingDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
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
        let showBlockingLoader = showFullScreenLoading && sessions.isEmpty
        if showBlockingLoader {
            isLoading = true
        }
        loadError = nil
        defer {
            if showBlockingLoader {
                isLoading = false
            }
        }
        do {
            sessions = try await apiClient.fetchSessions()
            voiceRouting.refreshExpiryIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
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
        sessionPendingVoiceDefault = session
        selectedVoiceDefaultTTL = .oneHour
        showVoiceDefaultTTLSheet = true
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
        if let remote = remoteBundle() {
            return remote
        }
        return StubAttachmentLoader()
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
        deepLinkVoiceRecording: .constant(false)
    )
}
