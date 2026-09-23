import SwiftUI

struct BoardsTabView: View {
    private let client: BoardsAPIClientProtocol
    @State private var viewModel: BoardsViewModel
    @State private var path = NavigationPath()

    init(client: BoardsAPIClientProtocol = BoardsTabView.makeClient()) {
        self.client = client
        _viewModel = State(initialValue: BoardsViewModel(client: client))
    }

    var body: some View {
        NavigationStack(path: $path) {
            listContent
                .navigationTitle("boards.title")
                .toolbar(path.isEmpty ? .automatic : .hidden, for: .tabBar)
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
                .navigationDestination(for: KBBoard.self) { board in
                    BoardDetailView(boardId: board.id, client: client)
                        .toolbar(.hidden, for: .tabBar)
                }
                .task {
                    await viewModel.loadIfNeeded()
                }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading, viewModel.boards.isEmpty {
            ProgressView("boards.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError = viewModel.loadError, viewModel.boards.isEmpty {
            ContentUnavailableView(
                "boards.could_not_load",
                systemImage: "exclamationmark.triangle",
                description: Text(loadError)
            )
        } else if viewModel.boards.isEmpty {
            ContentUnavailableView(
                "boards.empty_title",
                systemImage: "square.grid.2x2",
                description: Text("boards.empty_hint")
            )
        } else {
            List(viewModel.boards) { board in
                NavigationLink(value: board) {
                    BoardListCellView(board: board)
                }
            }
            .refreshable {
                await viewModel.reload()
            }
        }
    }

    static func makeClient() -> BoardsAPIClientProtocol {
        if let remote = URLSessionBoardsAPIClient() {
            return remote
        }
        return StubBoardsAPIClient()
    }
}

struct BoardListCellView: View {
    let board: KBBoard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: board.systemImageName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(BoardListPresentation.title(for: board))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = BoardListPresentation.subtitle(for: board) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let metrics = board.listCell?.metrics, !metrics.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(metrics.prefix(3).enumerated()), id: \.offset) { _, metric in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                if let status = board.listCell?.statusText, !status.isEmpty {
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch BoardListPresentation.statusTone(board.listCell?.statusTone) {
        case .ok:
            return .green
        case .warn:
            return .orange
        case .error:
            return .red
        case .info:
            return .accentColor
        }
    }
}

#Preview {
    BoardsTabView(client: StubBoardsAPIClient())
}
