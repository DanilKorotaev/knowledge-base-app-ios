import SwiftUI

struct MainView: View {
    private let apiClient: KnowledgeBaseAPIClientProtocol
    private let chatClient: ChatAPIClientProtocol
    @State private var sessions: [KBSession] = []
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var voiceViewModel = VoiceRecordingViewModel()
    @State private var showNewSession = false
    @State private var newSessionTitle = ""

    init(
        apiClient: KnowledgeBaseAPIClientProtocol = MainView.makeSessionClient(),
        chatClient: ChatAPIClientProtocol = MainView.makeChatClient()
    ) {
        self.apiClient = apiClient
        self.chatClient = chatClient
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
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(
                            "Configure the API in Settings, or use a stub build with a demo session when no server is set."
                        )
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        MicBar(viewModel: voiceViewModel)
                    }
                } else {
                    List(sessions) { session in
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
                    .navigationDestination(for: KBSession.self) { session in
                        ChatView(session: session, chatClient: chatClient)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        MicBar(viewModel: voiceViewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Knowledge Base")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await loadSessions() }
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
            .task {
                await loadSessions()
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
                PostRecordingReviewSheet(viewModel: voice)
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
        }
    }

    @MainActor
    private func loadSessions() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
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
            await loadSessions()
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
}

private struct MicBar: View {
    @Bindable var viewModel: VoiceRecordingViewModel

    var body: some View {
        MicRecordControl(viewModel: viewModel)
            .padding(.horizontal)
            .background(.bar)
    }
}

#Preview {
    MainView(
        apiClient: StubKnowledgeBaseAPIClient(store: InMemoryKBStore()),
        chatClient: StubChatAPIClient(store: InMemoryKBStore())
    )
}
