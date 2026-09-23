import Foundation
import Observation

@MainActor
@Observable
final class BoardsViewModel {
    private let client: BoardsAPIClientProtocol

    var boards: [KBBoard] = []
    var isLoading = false
    var isRefreshing = false
    var loadError: String?
    var didLoadOnce = false

    init(client: BoardsAPIClientProtocol) {
        self.client = client
    }

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await load(showFullScreenLoading: true)
    }

    func reload() async {
        await load(showFullScreenLoading: boards.isEmpty)
    }

    func load(showFullScreenLoading: Bool) async {
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
            boards = try await client.fetchBoards()
        } catch {
            if boards.isEmpty {
                loadError = error.localizedDescription
            }
        }
    }
}

@MainActor
@Observable
final class BoardDetailViewModel {
    private let client: BoardsAPIClientProtocol
    let boardId: String

    var detail: KBBoardDetail?
    var isLoading = false
    var isRefreshing = false
    var loadError: String?

    init(boardId: String, client: BoardsAPIClientProtocol) {
        self.boardId = boardId
        self.client = client
    }

    func load() async {
        isLoading = detail == nil
        loadError = nil
        defer { isLoading = false }

        do {
            detail = try await client.fetchBoard(id: boardId)
        } catch {
            if detail == nil {
                loadError = error.localizedDescription
            }
        }
    }

    func refresh() async {
        isRefreshing = true
        loadError = nil
        defer { isRefreshing = false }

        do {
            detail = try await client.refreshBoard(id: boardId)
        } catch {
            if detail == nil {
                loadError = error.localizedDescription
            }
        }
    }
}
