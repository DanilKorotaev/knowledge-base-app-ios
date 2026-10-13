import XCTest
@testable import KnowledgeBaseApp

final class ActionsBoardIDsTests: XCTestCase {
    func testJobsBoardIdsAreHiddenFromOverview() {
        XCTAssertTrue(ActionsBoardIDs.isJobsBoard("active-jobs"))
        XCTAssertTrue(ActionsBoardIDs.isHiddenFromOverview("demo-active-jobs"))
        XCTAssertFalse(ActionsBoardIDs.isHiddenFromOverview("workouts"))
    }
}
