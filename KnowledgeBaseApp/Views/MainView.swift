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
        NavigationStack {
            Group {
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
                        MicBar(viewModel: voiceViewModel)
                    }
                } else {
                    List(displayedSessions) { session in
                        NavigationLink(value: session) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.headline)
                                Text("\(session.messageCount) messages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .refreshable {
                        await loadSessions(showFullScreenLoading: false)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        MicBar(viewModel: voiceViewModel)
                    }
                }
            }
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
            .onChange(of: deepLinkVoiceRecording) { _, newValue in
                guard newValue else { return }
                Task {
                    try? await Task.sleep(for: .seconds(12))
                    await MainActor.run {
                        deepLinkVoiceRecording = false
                    }
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
    }

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    /// В режиме записи панель тянется на всю ширину; в idle — небольшие боковые отступы у микрофона.
    private var horizontalPadding: CGFloat {
        viewModel.phase == .idle ? 16 : 0
    }

    var body: some View {
        MicRecordControl(viewModel: viewModel)
            .padding(.horizontal, horizontalPadding)
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
