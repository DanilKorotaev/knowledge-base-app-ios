import XCTest
@testable import KnowledgeBaseApp

final class OfflineCacheStoreTests: XCTestCase {
    private var cacheDir: URL!
    private var store: FileOfflineCacheStore!

    override func setUp() {
        super.setUp()
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-cache-tests-\(UUID().uuidString)", isDirectory: true)
        store = FileOfflineCacheStore(baseURL: cacheDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDir)
        super.tearDown()
    }

    func testSaveAndLoadSessions() {
        let sessions = [
            KBSession(id: "1", title: "Alpha", messageCount: 2, updatedAt: Date()),
            KBSession(id: "2", title: "Beta", messageCount: 0, updatedAt: Date()),
        ]
        store.saveSessions(sessions)

        let loaded = store.loadSessions()
        XCTAssertEqual(loaded?.map(\.id), ["1", "2"])
        XCTAssertNotNil(store.lastSessionsSyncAt())
    }

    func testUpsertSessionUpdatesTitle() {
        store.saveSessions([
            KBSession(id: "1", title: "Old", messageCount: 0, updatedAt: Date()),
        ])
        store.upsertSession(KBSession(id: "1", title: "New", messageCount: 3, updatedAt: Date()))

        XCTAssertEqual(store.loadSessions()?.first?.title, "New")
        XCTAssertEqual(store.loadSessions()?.first?.messageCount, 3)
    }

    func testRemoveSessionDeletesSessionsAndMessages() {
        store.saveSessions([
            KBSession(id: "s1", title: "Chat", messageCount: 1, updatedAt: Date()),
        ])
        let message = KBMessage(id: "m1", role: .user, content: "hi", createdAt: Date())
        store.saveWindow(
            sessionId: "s1",
            page: KBMessagesPage(messages: [message], total: 1, hasMoreOlder: false)
        )

        store.removeSession(id: "s1")

        XCTAssertTrue(store.loadSessions()?.isEmpty ?? false)
        XCTAssertNil(store.loadWindow(sessionId: "s1"))
    }

    func testMessageWindowRoundTripPreservesOrder() {
        let messages = [
            KBMessage(id: "m1", role: .user, content: "one", createdAt: Date()),
            KBMessage(id: "m2", role: .assistant, content: "two", createdAt: Date()),
        ]
        store.saveWindow(
            sessionId: "42",
            page: KBMessagesPage(messages: messages, total: 10, hasMoreOlder: true)
        )

        let loaded = store.loadWindow(sessionId: "42")
        XCTAssertEqual(loaded?.messages.map(\.id), ["m1", "m2"])
        XCTAssertEqual(loaded?.total, 10)
        XCTAssertTrue(loaded?.hasMoreOlder ?? false)
        XCTAssertNotNil(store.lastSyncedAt(sessionId: "42"))
    }
}
