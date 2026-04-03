import SwiftUI

struct MainView: View {
    private let apiClient: KnowledgeBaseAPIClientProtocol
    @State private var sessions: [KBSession] = []
    @State private var loadError: String?
    @State private var isLoading = false

    init(apiClient: KnowledgeBaseAPIClientProtocol = MainView.makeDefaultClient()) {
        self.apiClient = apiClient
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
                            "Configure the API in Settings. Until the KB App API is deployed, the list stays empty."
                        )
                    )
                } else {
                    List(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text("\(session.messageCount) messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .task {
                await loadSessions()
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

    private static func makeDefaultClient() -> KnowledgeBaseAPIClientProtocol {
        if let remote = URLSessionKnowledgeBaseAPIClient() {
            return remote
        }
        return StubKnowledgeBaseAPIClient()
    }
}

#Preview {
    MainView(apiClient: StubKnowledgeBaseAPIClient())
}
