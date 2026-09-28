import SwiftUI

struct BoardsArchiveView: View {
    private let client: BoardsAPIClientProtocol
    @State private var viewModel: BoardsArchiveViewModel

    init(client: BoardsAPIClientProtocol) {
        self.client = client
        _viewModel = State(initialValue: BoardsArchiveViewModel(client: client))
    }

    var body: some View {
        Group {
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
                    "boards.archive.empty_title",
                    systemImage: "archivebox",
                    description: Text("boards.archive.empty_hint")
                )
            } else {
                List {
                    ForEach(viewModel.boards) { board in
                        BoardListCellView(board: board)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await viewModel.restore(board) }
                                } label: {
                                    Label("boards.restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.accentColor)
                            }
                            .contextMenu {
                                Button {
                                    Task { await viewModel.restore(board) }
                                } label: {
                                    Label("boards.restore", systemImage: "arrow.uturn.backward")
                                }
                            }
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("boards.archive.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("common.refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        BoardsArchiveView(client: StubBoardsAPIClient())
    }
}
