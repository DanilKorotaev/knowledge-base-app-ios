import XCTest
@testable import KnowledgeBaseApp

final class SessionKBModeStoreTests: XCTestCase {
    private var storage: UserDefaults!
    private var previousShared: UserDefaultsServiceDescription!
    private var store: SessionKBModeStore!
    private var suiteName: String!

    override func setUpWithError() throws {
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        storage = isolated.storage
        suiteName = isolated.suiteName
        previousShared = UserDefaultsService.shared
        UserDefaultsService.shared = UserDefaultsService(storage: storage)
        store = SessionKBModeStore(sharedSuite: nil)
    }

    override func tearDownWithError() throws {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
    }

    func testSaveLoadAndRemove() {
        store.save(sessionId: "42", useKnowledgeBase: false)
        XCTAssertEqual(store.load(sessionId: "42"), false)

        store.remove(sessionId: "42")
        XCTAssertNil(store.load(sessionId: "42"))
    }

    func testUseKnowledgeBasePrefersStoredValue() {
        let session = KBSession(id: "1", title: "Chat", messageCount: 0, updatedAt: nil, useKnowledgeBase: true)
        store.save(sessionId: "1", useKnowledgeBase: false)
        XCTAssertFalse(store.useKnowledgeBase(for: session))
    }

    func testUseKnowledgeBaseFallsBackToSessionField() {
        let session = KBSession(id: "2", title: "Chat", messageCount: 0, updatedAt: nil, useKnowledgeBase: false)
        XCTAssertFalse(store.useKnowledgeBase(for: session))
    }

    func testPruneRemovesStaleSessions() {
        store.save(sessionId: "keep", useKnowledgeBase: true)
        store.save(sessionId: "drop", useKnowledgeBase: false)
        store.prune(validSessionIds: ["keep"])
        XCTAssertNotNil(store.load(sessionId: "keep"))
        XCTAssertNil(store.load(sessionId: "drop"))
    }
}

@MainActor
final class ChatViewModelSessionKBModeTests: XCTestCase {
    func testUsesPersistedSessionKBMode() {
        let store = SessionKBModeStore(sharedSuite: nil)
        store.save(sessionId: "s1", useKnowledgeBase: false)
        let session = KBSession(id: "s1", title: "Chat", messageCount: 0, updatedAt: nil, useKnowledgeBase: true)
        let viewModel = ChatViewModel(
            session: session,
            client: StubChatAPIClient(store: InMemoryKBStore(demoSession: false)),
            sessionKBModeStore: store
        )
        XCTAssertFalse(viewModel.useKnowledgeBase)
    }
}
