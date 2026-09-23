import SwiftUI
import UIKit
import Testing
@testable import KnowledgeBaseApp

@MainActor
enum ViewCoverageHost {
    static func render<V: View>(_ view: V, settleNanoseconds: UInt64 = 30_000_000) async {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        await Task.yield()
        try? await Task.sleep(nanoseconds: settleNanoseconds)
        window.isHidden = true
    }
}

@MainActor
@Suite("Boards view coverage")
struct BoardsViewCoverageTests {
    @Test("render boards list cells and detail")
    func renderBoards() async {
        await ViewCoverageHost.render(BoardsTabView(client: StubBoardsAPIClient()), settleNanoseconds: 120_000_000)

        for board in DemoBoardsCatalog.boards() {
            await ViewCoverageHost.render(BoardListCellView(board: board))
        }

        await ViewCoverageHost.render(
            BoardListCellView(
                board: KBBoard(
                    id: "warn",
                    title: "Warn",
                    listCell: KBBoardListCell(statusText: "down", statusTone: "warn")
                )
            )
        )
        await ViewCoverageHost.render(
            BoardListCellView(
                board: KBBoard(
                    id: "err",
                    title: "Err",
                    listCell: KBBoardListCell(statusText: "fail", statusTone: "error")
                )
            )
        )
        await ViewCoverageHost.render(
            BoardListCellView(
                board: KBBoard(
                    id: "ok",
                    title: "Ok",
                    listCell: KBBoardListCell(statusText: "up", statusTone: "success")
                )
            )
        )

        await ViewCoverageHost.render(
            NavigationStack {
                BoardDetailView(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
            },
            settleNanoseconds: 150_000_000
        )
        await ViewCoverageHost.render(
            NavigationStack {
                BoardDetailView(boardId: DemoBoardsCatalog.demoJobsId, client: StubBoardsAPIClient())
            },
            settleNanoseconds: 150_000_000
        )
        await ViewCoverageHost.render(
            NavigationStack {
                BoardDetailView(boardId: "missing", client: StubBoardsAPIClient())
            },
            settleNanoseconds: 100_000_000
        )
    }

    @Test("render metric table and demo panel")
    func renderNodes() async {
        await ViewCoverageHost.render(
            StructuredUIMetricNodeView(
                node: KBStructuredUINode(type: "metric", id: "m", text: "42", label: "Total")
            )
        )
        await ViewCoverageHost.render(
            StructuredUIMetricNodeView(node: KBStructuredUINode(type: "metric", id: "m2"))
        )
        await ViewCoverageHost.render(
            StructuredUITableNodeView(
                node: KBStructuredUINode(
                    type: "table",
                    id: "t",
                    label: "Rows",
                    columns: [
                        KBStructuredUITableColumn(id: "a", label: "A"),
                        KBStructuredUITableColumn(id: "b", label: "B"),
                    ],
                    rows: [["1", "2"], ["3"]]
                )
            )
        )
        await ViewCoverageHost.render(
            StructuredUITableNodeView(node: KBStructuredUINode(type: "table", id: "empty"))
        )

        if let document = DemoBoardsCatalog.detail(id: DemoBoardsCatalog.demoKPIId)?.document {
            await ViewCoverageHost.render(
                StructuredUIPanelView(
                    document: document,
                    isSending: false,
                    isInteractive: false,
                    attachmentLoader: nil,
                    onFullscreenImage: nil,
                    onAction: { _, _, _ in }
                )
            )
        }
    }
}
