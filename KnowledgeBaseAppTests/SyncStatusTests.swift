import XCTest
@testable import KnowledgeBaseApp

final class SyncStatusTests: XCTestCase {
    override func tearDown() {
        AppLanguageStore.shared.resetForTesting()
        super.tearDown()
    }

    func testDisplayText_refreshing_russian() {
        AppLanguageStore.shared.setOverride(.russian)
        XCTAssertEqual(SyncStatus.refreshing.displayText, "Обновление…")
    }

    func testDisplayText_refreshing_english() {
        AppLanguageStore.shared.setOverride(.english)
        XCTAssertEqual(SyncStatus.refreshing.displayText, "Updating…")
    }

    func testDisplayText_offlineWithoutDate() {
        AppLanguageStore.shared.setOverride(.russian)
        XCTAssertEqual(SyncStatus.offline(lastSyncedAt: nil).displayText, "Офлайн")

        AppLanguageStore.shared.setOverride(.english)
        XCTAssertEqual(SyncStatus.offline(lastSyncedAt: nil).displayText, "Offline")
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

    func testRelativeAge_returnsNonEmptyForRecentDate() {
        AppLanguageStore.shared.setOverride(.russian)
        let text = SyncStatusFormatting.relativeAge(since: Date())
        XCTAssertFalse(text.isEmpty)
    }
}
