import SwiftUI

/// Shell tab for actionable Structured UI (jobs cancel today; presets later).
struct ActionsTabView: View {
    private let client: BoardsAPIClientProtocol
    @State private var jobsBoardId: String?
    @State private var isLoading = true
    @State private var loadError: String?

    init(client: BoardsAPIClientProtocol = ActionsTabView.makeClient()) {
        self.client = client
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading, jobsBoardId == nil {
                    ProgressView("actions.loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError, jobsBoardId == nil {
                    ContentUnavailableView(
                        "actions.could_not_load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else if let jobsBoardId {
                    BoardDetailView(boardId: jobsBoardId, client: client)
                        .id(jobsBoardId)
                } else {
                    ContentUnavailableView(
                        "actions.empty_title",
                        systemImage: "bolt.horizontal.circle",
                        description: Text("actions.empty_hint")
                    )
                }
            }
        }
        .task {
            await resolveJobsBoard()
        }
    }

    @MainActor
    private func resolveJobsBoard() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let boards = try await client.fetchBoards()
            if let match = boards.first(where: { ActionsBoardIDs.isJobsBoard($0.id) }) {
                jobsBoardId = match.id
                return
            }
            // Prefer production id; fall back to demo catalog id if fetch works.
            for candidate in [ActionsBoardIDs.preferredJobsBoardId, DemoBoardsCatalog.demoJobsId] {
                do {
                    _ = try await client.fetchBoard(id: candidate, query: .all)
                    jobsBoardId = candidate
                    return
                } catch {
                    continue
                }
            }
            jobsBoardId = ActionsBoardIDs.preferredJobsBoardId
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func makeClient() -> BoardsAPIClientProtocol {
        if let remote = URLSessionBoardsAPIClient() {
            return remote
        }
        return StubBoardsAPIClient()
    }
}

enum ActionsBoardIDs {
    /// Production system board, then demo catalog fallback.
    static let preferredJobsBoardId = "active-jobs"
    static let jobsBoardIds: Set<String> = ["active-jobs", "demo-active-jobs"]

    static func isJobsBoard(_ id: String) -> Bool {
        jobsBoardIds.contains(id)
    }

    /// Overview should not duplicate jobs once Actions tab owns them.
    static func isHiddenFromOverview(_ id: String) -> Bool {
        isJobsBoard(id)
    }
}
