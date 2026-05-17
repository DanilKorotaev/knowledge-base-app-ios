import XCTest
@testable import KnowledgeBaseApp

final class InMemoryKBStoreTests: XCTestCase {
    func testDemoSessionByDefault() {
        let store = InMemoryKBStore()
        let sessions = store.sessionsSnapshot()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, "demo-session")
    }

    func testCreateSessionAndMessages() {
        let store = InMemoryKBStore(demoSession: false)
        let created = store.createSession(title: "  Work  ")
        XCTAssertEqual(created.title, "Work")

        let message = KBMessage(id: "m1", role: .user, content: "hi", createdAt: Date())
        store.replaceMessages([message], sessionId: created.id)

        XCTAssertEqual(store.messages(for: created.id).count, 1)
        let sessions = store.sessionsSnapshot()
        XCTAssertEqual(sessions.first?.messageCount, 1)
    }

    func testCreateSessionUsesDefaultTitleWhenEmpty() {
        let store = InMemoryKBStore(demoSession: false)
        let created = store.createSession(title: "   ")
        XCTAssertEqual(created.title, "New session")
    }
}
