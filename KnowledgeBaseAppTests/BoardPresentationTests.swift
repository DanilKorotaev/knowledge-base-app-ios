import Foundation
import Testing
@testable import KnowledgeBaseApp

@Suite("BoardPresentation")
struct BoardPresentationTests {
    @Test("list title prefers list_cell")
    func title() {
        let board = KBBoard(
            id: "1",
            title: "Fallback",
            listCell: KBBoardListCell(title: "Cell title")
        )
        #expect(BoardListPresentation.title(for: board) == "Cell title")
        #expect(BoardListPresentation.title(for: KBBoard(id: "2", title: "Only")) == "Only")
    }

    @Test("subtitle ignores empty")
    func subtitle() {
        let empty = KBBoard(id: "1", title: "A", subtitle: "")
        #expect(BoardListPresentation.subtitle(for: empty) == nil)
        let cell = KBBoard(
            id: "2",
            title: "A",
            listCell: KBBoardListCell(subtitle: "From cell")
        )
        #expect(BoardListPresentation.subtitle(for: cell) == "From cell")
    }

    @Test("status tone mapping")
    func tones() {
        #expect(BoardListPresentation.statusTone("ok") == .ok)
        #expect(BoardListPresentation.statusTone("success") == .ok)
        #expect(BoardListPresentation.statusTone("warn") == .warn)
        #expect(BoardListPresentation.statusTone("warning") == .warn)
        #expect(BoardListPresentation.statusTone("error") == .error)
        #expect(BoardListPresentation.statusTone("info") == .info)
        #expect(BoardListPresentation.statusTone(nil) == .info)
    }

    @Test("metric display formats values")
    func metricDisplay() {
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", text: "12")
            ) == "12"
        )
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", value: .number(3))
            ) == "3"
        )
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", value: .number(3.5))
            ) == "3.5"
        )
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", value: .bool(true))
            ) == "true"
        )
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", value: .strings(["a", "b"]))
            ) == "a, b"
        )
        #expect(
            StructuredUIMetricDisplay.value(
                from: KBStructuredUINode(type: "metric", id: "m", value: .string("x"))
            ) == "x"
        )
        #expect(
            StructuredUIMetricDisplay.value(from: KBStructuredUINode(type: "metric", id: "m")) == "—"
        )
        #expect(
            StructuredUIMetricDisplay.accessibilityLabel(
                from: KBStructuredUINode(type: "metric", id: "m", text: "9", label: "Total")
            ) == "Total: 9"
        )
        #expect(
            StructuredUIMetricDisplay.accessibilityLabel(
                from: KBStructuredUINode(type: "metric", id: "m", text: "9")
            ) == "9"
        )
    }

    @Test("table display helpers")
    func tableDisplay() {
        let columns = [KBStructuredUITableColumn(id: "a", label: "A")]
        let rows = [["1", "2"], ["3"]]
        #expect(StructuredUITableDisplay.columnCount(columns: columns, rows: rows) == 2)
        #expect(StructuredUITableDisplay.cell(["x"], at: 0) == "x")
        #expect(StructuredUITableDisplay.cell(["x"], at: 3) == "")
        #expect(StructuredUITableDisplay.columnCount(columns: [], rows: []) == 0)
        #expect(StructuredUITableDisplay.allowsHorizontalScroll(scrollHorizontal: nil, columnCount: 4))
        #expect(!StructuredUITableDisplay.allowsHorizontalScroll(scrollHorizontal: nil, columnCount: 3))
        #expect(!StructuredUITableDisplay.allowsHorizontalScroll(scrollHorizontal: false, columnCount: 10))
        #expect(StructuredUITableDisplay.allowsHorizontalScroll(scrollHorizontal: true, columnCount: 1))
    }

    @Test("demo catalog details cover both boards")
    func demoCatalog() {
        let boards = DemoBoardsCatalog.boards()
        #expect(boards.count == 2)
        for board in boards {
            let detail = DemoBoardsCatalog.detail(id: board.id)
            #expect(detail != nil)
            #expect(detail?.document.isSupportedByClient == true)
        }
        #expect(DemoBoardsCatalog.detail(id: "missing") == nil)
    }

    @Test("board encode decode round trip")
    func roundTrip() throws {
        let board = KBBoard(
            id: "r1",
            title: "Round",
            subtitle: "sub",
            icon: "star",
            kind: "remote",
            sortOrder: 3,
            enabled: true,
            listCell: KBBoardListCell(
                kind: "status",
                title: "T",
                statusText: "up",
                statusTone: "ok"
            ),
            renderedAt: "2026-01-01T00:00:00Z"
        )
        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(KBBoard.self, from: data)
        #expect(decoded == board)

        let list = KBBoardsListResponse(boards: [board], total: 1)
        let listData = try JSONEncoder().encode(list)
        let listDecoded = try JSONDecoder().decode(KBBoardsListResponse.self, from: listData)
        #expect(listDecoded.boards == [board])
    }
}

private final class FailingBoardsClient: BoardsAPIClientProtocol, @unchecked Sendable {
    func fetchBoards() async throws -> [KBBoard] {
        throw BoardsAPIError.invalidResponse(statusCode: 500)
    }

    func fetchBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        _ = id
        _ = query
        throw BoardsAPIError.notFound
    }

    func refreshBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        _ = id
        _ = query
        throw BoardsAPIError.invalidResponse(statusCode: 503)
    }
}

@MainActor
@Suite("BoardsViewModel errors")
struct BoardsViewModelErrorTests {
    @Test("load error when empty")
    func loadError() async {
        let vm = BoardsViewModel(client: FailingBoardsClient())
        await vm.reload()
        #expect(vm.boards.isEmpty)
        #expect(vm.loadError != nil)
    }

    @Test("refresh error keeps existing detail")
    func refreshKeepsDetail() async {
        let vm = BoardDetailViewModel(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
        await vm.load()
        #expect(vm.detail != nil)

        let failing = BoardDetailViewModel(boardId: DemoBoardsCatalog.demoKPIId, client: FailingBoardsClient())
        failing.detail = vm.detail
        await failing.refresh()
        #expect(failing.detail != nil)
        #expect(failing.loadError == nil)
    }
}
