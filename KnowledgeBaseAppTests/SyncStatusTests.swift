import XCTest
@testable import KnowledgeBaseApp

final class SyncStatusTests: XCTestCase {
    func testDisplayText_refreshing() {
        XCTAssertEqual(SyncStatus.refreshing.displayText, "Обновление…")
    }

    func testDisplayText_offlineWithoutDate() {
        XCTAssertEqual(SyncStatus.offline(lastSyncedAt: nil).displayText, "Офлайн")
    }

    func testDisplayText_failedIncludesMessage() {
        let status = SyncStatus.failed(message: "Timeout", lastSyncedAt: nil)
        XCTAssertEqual(status.displayText, "Timeout")
    }

    func testShowsBanner() {
        XCTAssertFalse(SyncStatus.idle.showsBanner)
        XCTAssertTrue(SyncStatus.refreshing.showsBanner)
        XCTAssertTrue(SyncStatus.upToDate(lastSyncedAt: Date()).showsBanner)
        XCTAssertTrue(SyncStatus.offline(lastSyncedAt: Date()).showsBanner)
    }

    func testIsProminent_onlyForActiveProblems() {
        XCTAssertTrue(SyncStatus.refreshing.isProminent)
        XCTAssertTrue(SyncStatus.offline(lastSyncedAt: nil).isProminent)
        XCTAssertTrue(SyncStatus.failed(message: "x", lastSyncedAt: nil).isProminent)
        XCTAssertFalse(SyncStatus.upToDate(lastSyncedAt: Date()).isProminent)
    }

    func testSyncNetworkError_detectsURLOfflineCodes() {
        let offline = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
        XCTAssertTrue(SyncNetworkError.isOffline(offline))

        let other = NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue)
        XCTAssertFalse(SyncNetworkError.isOffline(other))
    }

    func testSyncNetworkError_failureStatus_offlineWhenPathDown() {
        let error = NSError(domain: "test", code: 1)
        let status = SyncNetworkError.failureStatus(
            error: error,
            lastSyncedAt: Date(),
            isPathOnline: false
        )
        if case .offline = status {
            XCTAssertNotNil(status.lastSyncedAt)
        } else {
            XCTFail("Expected offline")
        }
    }

    func testRelativeAge_justNow() {
        let text = SyncStatusFormatting.relativeAge(since: Date())
        XCTAssertEqual(text, "только что")
    }
}
