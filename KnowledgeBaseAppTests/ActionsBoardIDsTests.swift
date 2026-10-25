import XCTest
@testable import KnowledgeBaseApp

final class ActionsBoardIDsTests: XCTestCase {
    func testJobsBoardIdsAreHiddenFromOverview() {
        XCTAssertTrue(ActionsBoardIDs.isJobsBoard("active-jobs"))
        XCTAssertTrue(ActionsBoardIDs.isHiddenFromOverview("demo-active-jobs"))
        XCTAssertTrue(ActionsBoardIDs.isPresetsBoard("actions-presets"))
        XCTAssertTrue(ActionsBoardIDs.isHiddenFromOverview("actions-presets"))
        XCTAssertFalse(ActionsBoardIDs.isHiddenFromOverview("workouts"))
    }
}

@MainActor
final class ActionsTabViewModelTests: XCTestCase {
    func testEmptyBoardsList_showsEmptyNotError() async {
        let vm = ActionsTabViewModel(client: EmptyBoardsAPIClient())
        await vm.loadIfNeeded()
        XCTAssertNil(vm.loadError)
        XCTAssertFalse(vm.hasContent)
        XCTAssertNil(vm.presetsDetail)
        XCTAssertNil(vm.jobsDetail)
    }
}

/// Boards list without actions/presets boards (staging-like).
private final class EmptyBoardsAPIClient: BoardsAPIClientProtocol, @unchecked Sendable {
    func fetchBoards() async throws -> [KBBoard] { [] }

    func fetchBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        _ = query
        throw BoardsAPIError.notFound
    }

    func refreshBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        try await fetchBoard(id: id, query: query)
    }
}
