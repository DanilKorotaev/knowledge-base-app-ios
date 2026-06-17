import XCTest
@testable import KnowledgeBaseApp

final class SessionListSorterTests: XCTestCase {
    private func session(_ id: String) -> KBSession {
        KBSession(id: id, title: id, messageCount: 0, updatedAt: nil)
    }

    func testEmptyPinsReturnsApiOrder() {
        let sessions = [session("1"), session("2"), session("3")]
        let sorted = SessionListSorter.displayOrder(sessions: sessions, pinnedIds: [])
        XCTAssertEqual(sorted.map(\.id), ["1", "2", "3"])
    }

    func testPinnedSessionsAppearFirstInPinOrder() {
        let sessions = [session("1"), session("2"), session("3")]
        let sorted = SessionListSorter.displayOrder(sessions: sessions, pinnedIds: ["3", "1"])
        XCTAssertEqual(sorted.map(\.id), ["3", "1", "2"])
    }

    func testUnknownPinnedIdsAreSkipped() {
        let sessions = [session("1"), session("2")]
        let sorted = SessionListSorter.displayOrder(sessions: sessions, pinnedIds: ["missing", "2"])
        XCTAssertEqual(sorted.map(\.id), ["2", "1"])
    }

    func testRePinOrderMovesSessionHigher() {
        let sessions = [session("a"), session("b"), session("c")]
        var pinned = ["b", "a"]
        var sorted = SessionListSorter.displayOrder(sessions: sessions, pinnedIds: pinned)
        XCTAssertEqual(sorted.map(\.id), ["b", "a", "c"])

        pinned = ["a", "b"]
        sorted = SessionListSorter.displayOrder(sessions: sessions, pinnedIds: pinned)
        XCTAssertEqual(sorted.map(\.id), ["a", "b", "c"])
    }
}
