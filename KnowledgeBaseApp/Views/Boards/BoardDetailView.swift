import SwiftUI

struct BoardDetailView: View {
    @State private var viewModel: BoardDetailViewModel

    init(boardId: String, client: BoardsAPIClientProtocol) {
        _viewModel = State(initialValue: BoardDetailViewModel(boardId: boardId, client: client))
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.detail == nil {
                ProgressView("boards.loading_detail")
            } else if let loadError = viewModel.loadError, viewModel.detail == nil {
                ContentUnavailableView(
                    "boards.could_not_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if let detail = viewModel.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let subtitle = detail.board.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        StructuredUIPanelView(
                            document: detail.document,
                            isSending: false,
                            isInteractive: false,
                            attachmentLoader: nil,
                            onFullscreenImage: nil,
                            onAction: { _, _, _ in }
                        )
                        if let renderedAt = detail.renderedAt ?? detail.board.renderedAt {
                            Text(L10n.format("boards.rendered_at_format", renderedAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            } else {
                ContentUnavailableView(
                    "boards.empty_title",
                    systemImage: "square.grid.2x2",
                    description: Text("boards.empty_hint")
                )
            }
        }
        .navigationTitle(viewModel.detail?.board.title ?? "boards.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("common.refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading || viewModel.isRefreshing)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
    }
}
