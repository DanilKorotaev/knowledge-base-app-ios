import SwiftUI

/// Actions tab: config-driven presets (Structured UI) + active Cursor jobs — separate sections.
struct ActionsTabView: View {
    @State private var viewModel: ActionsTabViewModel

    init(client: BoardsAPIClientProtocol = ActionsTabView.makeClient()) {
        _viewModel = State(initialValue: ActionsTabViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading, !viewModel.hasContent {
                    ProgressView("actions.loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError = viewModel.loadError, !viewModel.hasContent {
                    ContentUnavailableView(
                        "actions.could_not_load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else if viewModel.hasContent {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let presets = viewModel.presetsDetail {
                                actionsSection(
                                    title: presets.board.title,
                                    detail: presets,
                                    cancelsJobs: false
                                )
                            }
                            if let jobs = viewModel.jobsDetail {
                                actionsSection(
                                    title: jobs.board.title,
                                    detail: jobs,
                                    cancelsJobs: true
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.reload()
                    }
                } else {
                    ContentUnavailableView(
                        "actions.empty_title",
                        systemImage: "bolt.horizontal.circle",
                        description: Text("actions.empty_hint")
                    )
                }
            }
            .navigationTitle("tab.actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Label("common.refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading || viewModel.isRefreshing)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func actionsSection(
        title: String,
        detail: KBBoardDetail,
        cancelsJobs: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            StructuredUIPanelView(
                document: detail.document,
                isSending: cancelsJobs && viewModel.isCancellingJob,
                isInteractive: detail.document.hasInteractiveControls
                    || detail.document.hasAppActions,
                attachmentLoader: nil,
                onFullscreenImage: nil,
                onAction: { actionId, componentId, _ in
                    guard cancelsJobs, actionId == "cancel_job" else { return }
                    Task { await viewModel.cancelJob(id: componentId) }
                },
                onAppAction: { action, _ in
                    KBAppActionCenter.shared.perform(action)
                }
            )
        }
        .accessibilityIdentifier("actions.section.\(detail.board.id)")
    }

    private static func makeClient() -> BoardsAPIClientProtocol {
        if UITestRuntime.isUITesting {
            return StubBoardsAPIClient()
        }
        if let remote = URLSessionBoardsAPIClient() {
            return remote
        }
        return StubBoardsAPIClient()
    }
}

@MainActor
@Observable
final class ActionsTabViewModel {
    private let client: BoardsAPIClientProtocol

    var presetsDetail: KBBoardDetail?
    var jobsDetail: KBBoardDetail?
    var isLoading = false
    var isRefreshing = false
    var isCancellingJob = false
    var loadError: String?
    private var didLoadOnce = false

    var hasContent: Bool {
        presetsDetail != nil || jobsDetail != nil
    }

    init(client: BoardsAPIClientProtocol) {
        self.client = client
    }

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await load(showFullScreenLoading: true)
    }

    func reload() async {
        await load(showFullScreenLoading: !hasContent)
    }

    func cancelJob(id: String) async {
        isCancellingJob = true
        defer { isCancellingJob = false }
        do {
            try await client.cancelQueryJob(id: id)
            if let jobsId = jobsDetail?.board.id {
                jobsDetail = try await client.refreshBoard(id: jobsId, query: .all)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func load(showFullScreenLoading: Bool) async {
        if showFullScreenLoading {
            isLoading = true
        } else {
            isRefreshing = true
        }
        loadError = nil
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let boards = try await client.fetchBoards()
            let presetsId = boards.first(where: { ActionsBoardIDs.isPresetsBoard($0.id) })?.id
                ?? ActionsBoardIDs.preferredPresetsBoardId
            let jobsId = boards.first(where: { ActionsBoardIDs.isJobsBoard($0.id) })?.id
                ?? ActionsBoardIDs.preferredJobsBoardId

            async let presets = fetchDetailOptional(id: presetsId)
            async let jobs = fetchDetailOptional(id: jobsId)
            let (presetsResult, jobsResult) = try await (presets, jobs)
            presetsDetail = presetsResult
            jobsDetail = jobsResult
            if presetsDetail == nil, jobsDetail == nil {
                loadError = L10n.string("actions.could_not_load")
            }
        } catch {
            if !hasContent {
                loadError = error.localizedDescription
            }
        }
    }

    private func fetchDetailOptional(id: String) async throws -> KBBoardDetail? {
        do {
            return try await client.fetchBoard(id: id, query: .all)
        } catch {
            // Preferential ids may be missing until MCP upsert; keep the other section.
            return nil
        }
    }
}

enum ActionsBoardIDs {
    static let preferredJobsBoardId = "active-jobs"
    static let preferredPresetsBoardId = "actions-presets"
    static let jobsBoardIds: Set<String> = ["active-jobs", "demo-active-jobs"]

    static func isJobsBoard(_ id: String) -> Bool {
        jobsBoardIds.contains(id)
    }

    static func isPresetsBoard(_ id: String) -> Bool {
        id == preferredPresetsBoardId || id.hasPrefix("actions-")
    }

    /// Overview should not list Actions-owned boards (jobs + presets).
    static func isHiddenFromOverview(_ id: String) -> Bool {
        isJobsBoard(id) || isPresetsBoard(id)
    }
}
