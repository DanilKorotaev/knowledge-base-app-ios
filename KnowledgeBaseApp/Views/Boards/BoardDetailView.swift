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
                        periodBar
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

    private var periodBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.setPeriod(viewModel.period.shifting(byMonths: -1)) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("boards.period.previous"))

            VStack(spacing: 2) {
                Text(viewModel.period.displayLabel())
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Button("boards.period.all") {
                    Task { await viewModel.setPeriod(.all) }
                }
                .font(.caption)
                .disabled(viewModel.period == .all)
            }
            .frame(maxWidth: .infinity)

            Button {
                Task {
                    let next: BoardPeriodSelection =
                        viewModel.period == .all
                        ? BoardPeriodSelection.currentMonth()
                        : viewModel.period.shifting(byMonths: 1)
                    await viewModel.setPeriod(next)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("boards.period.next"))
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    NavigationStack {
        BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
    }
}
