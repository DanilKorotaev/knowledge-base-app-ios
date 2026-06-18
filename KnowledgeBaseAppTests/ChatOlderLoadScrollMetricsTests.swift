import XCTest
@testable import KnowledgeBaseApp

final class ChatOlderLoadScrollMetricsTests: XCTestCase {
    func testIsNearOldestLoadedEdge_whenAtNewestMessages_returnsFalse() {
        // Resting at bottom: large positive offset (from real device logs).
        XCTAssertFalse(
            ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(
                contentOffsetY: 1657,
                contentInsetTop: 0,
                contentHeight: 2277,
                containerHeight: 620
            )
        )
    }

    func testIsNearOldestLoadedEdge_whenScrolledTowardOlder_returnsTrue() {
        XCTAssertTrue(
            ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(
                contentOffsetY: -238,
                contentInsetTop: 116,
                contentHeight: 2252,
                containerHeight: 620
            )
        )
    }

    func testIsNearOldestLoadedEdge_whenContentFitsScreen_returnsFalse() {
        XCTAssertFalse(
            ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(
                contentOffsetY: 0,
                contentInsetTop: 0,
                contentHeight: 500,
                containerHeight: 700
            )
        )
    }

    func testMaxScrollOffset_whenContentShorterThanContainer_isZero() {
        XCTAssertEqual(
            ChatOlderLoadScrollMetrics.maxScrollOffset(contentHeight: 400, containerHeight: 700),
            0
        )
    }

    func testIsNearOldestLoadedEdge_whenMaxOffsetBelowThreshold_returnsFalse() {
        XCTAssertFalse(
            ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(
                contentOffsetY: 0,
                contentInsetTop: 0,
                contentHeight: 700,
                containerHeight: 620
            )
        )
    }

    func testDebugSnapshot_marksNearAsNo() {
        let snapshot = ChatOlderLoadScrollMetrics.debugSnapshot(
            contentOffsetY: 500,
            contentInsetTop: 0,
            contentHeight: 2000,
            containerHeight: 600
        )
        XCTAssertTrue(snapshot.contains("near=no"))
    }

    func testDebugSnapshot_includesNearFlag() {
        let snapshot = ChatOlderLoadScrollMetrics.debugSnapshot(
            contentOffsetY: -50,
            contentInsetTop: 100,
            contentHeight: 2000,
            containerHeight: 600
        )
        XCTAssertTrue(snapshot.contains("near=YES"))
        XCTAssertTrue(snapshot.contains("offsetY="))
    }

    func testIsNearOldestLoadedEdge_atInsetPlusThreshold_returnsTrue() {
        XCTAssertTrue(
            ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(
                contentOffsetY: 120,
                contentInsetTop: 0,
                contentHeight: 900,
                containerHeight: 600
            )
        )
    }
}
