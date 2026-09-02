import XCTest
@testable import KnowledgeBaseApp

final class PinnedSessionsStoreTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var previousShared: UserDefaultsServiceDescription!

    override func setUp() {
        super.setUp()
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        suiteName = isolated.suiteName
        storage = isolated.storage
        previousShared = UserDefaultsService.shared
        UserDefaultsService.shared = UserDefaultsService(storage: storage)
    }

    override func tearDown() {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testPinPrependsAndMovesExistingToTop() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "a")
        store.pin(sessionId: "b")
        XCTAssertEqual(store.loadOrderedIds(), ["b", "a"])

        store.pin(sessionId: "a")
        XCTAssertEqual(store.loadOrderedIds(), ["a", "b"])
    }

    func testUnpinRemovesId() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "a")
        store.pin(sessionId: "b")
        store.unpin(sessionId: "b")
        XCTAssertEqual(store.loadOrderedIds(), ["a"])
    }

    func testIsPinned() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "42")
        XCTAssertTrue(store.isPinned("42"))
        XCTAssertFalse(store.isPinned("7"))
    }

    func testRemoveSameAsUnpin() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "1")
        store.remove(sessionId: "1")
        XCTAssertTrue(store.loadOrderedIds().isEmpty)
    }

    func testPruneDropsMissingSessions() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "keep")
        store.pin(sessionId: "drop")
        store.prune(validSessionIds: ["keep"])
        XCTAssertEqual(store.loadOrderedIds(), ["keep"])
    }

    func testPruneNoOpWhenAllValid() {
        let store = PinnedSessionsStore(sharedSuite: nil)
        store.pin(sessionId: "a")
        store.pin(sessionId: "b")
        store.prune(validSessionIds: ["a", "b", "c"])
        XCTAssertEqual(store.loadOrderedIds(), ["b", "a"])
    }

    func testLoadReturnsEmptyForCorruptPayload() {
        storage.set(Data([0x00, 0x01]), forKey: UserDefaultsKey.pinnedSessionIds.rawValue)
        let store = PinnedSessionsStore(sharedSuite: nil)
        XCTAssertTrue(store.loadOrderedIds().isEmpty)
    }
}
