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
