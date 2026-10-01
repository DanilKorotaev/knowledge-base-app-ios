import SwiftUI

struct SessionsArchiveView: View {
    private let client: KnowledgeBaseAPIClientProtocol
    @State private var sessions: [KBSession] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var actionError: String?

    init(client: KnowledgeBaseAPIClientProtocol) {
        self.client = client
    }

    var body: some View {
        Group {
            if isLoading, sessions.isEmpty {
                ProgressView("common.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, sessions.isEmpty {
                ContentUnavailableView(
                    "sessions.archive.could_not_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "sessions.archive.empty_title",
                    systemImage: "archivebox",
                    description: Text("sessions.archive.empty_hint")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.body.weight(.medium))
                            Text("Session \(session.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                Task { await restore(session) }
                            } label: {
                                Label("sessions.restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.accentColor)
                        }
                        .contextMenu {
                            Button {
                                Task { await restore(session) }
                            } label: {
                                Label("sessions.restore", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle("sessions.archive.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Label("common.refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert("common.error", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("common.ok", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            sessions = try await client.fetchArchivedSessions()
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    private func restore(_ session: KBSession) async {
        do {
            _ = try await client.restoreSession(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            actionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SessionsArchiveView(client: StubKnowledgeBaseAPIClient())
    }
}
