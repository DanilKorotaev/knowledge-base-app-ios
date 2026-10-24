import XCTest
@testable import KnowledgeBaseApp

final class OfflineCacheScopeTests: XCTestCase {
    func testHostAndUserKeys() {
        let url = URL(string: "https://kbapp-staging.coredan.ru")!
        XCTAssertEqual(OfflineCacheScope.hostKey(from: url), "kbapp-staging.coredan.ru")
        XCTAssertEqual(OfflineCacheScope.userKey(userId: 4), "u4")
        XCTAssertEqual(OfflineCacheScope.userKey(userId: nil), "anonymous")
    }

    func testIsolationBetweenUsers() {
        let base = URL(string: "https://kbapp-staging.coredan.ru")!
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("scope-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let rootA = tmp
            .appendingPathComponent(OfflineCacheScope.hostKey(from: base), isDirectory: true)
            .appendingPathComponent(OfflineCacheScope.userKey(userId: 1), isDirectory: true)
        let rootB = tmp
            .appendingPathComponent(OfflineCacheScope.hostKey(from: base), isDirectory: true)
            .appendingPathComponent(OfflineCacheScope.userKey(userId: 2), isDirectory: true)

        let cacheA = FileOfflineCacheStore(baseURL: rootA)
        let cacheB = FileOfflineCacheStore(baseURL: rootB)
        let session = KBSession(id: "1", title: "A", messageCount: 0, updatedAt: Date())
        cacheA.saveSessions([session])

        XCTAssertEqual(cacheA.loadSessions()?.count, 1)
        XCTAssertNil(cacheB.loadSessions())
        XCTAssertNotEqual(rootA.path, rootB.path)
    }
}
