import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class ChatViewModelOverflowMenuTests: XCTestCase {
    func testSetUseKnowledgeBase_updatesDraftWithoutPersistingServerSession() {
        let store = InMemoryKBStore(demoSession: false)
        let viewModel = ChatViewModel(
            session: KBSession.makeLocalDraft(useKnowledgeBase: true),
            client: StubChatAPIClient(store: store),
            sessionCreator: StubKnowledgeBaseAPIClient(store: store)
        )

        viewModel.setUseKnowledgeBase(false)

        XCTAssertFalse(viewModel.useKnowledgeBase)
        XCTAssertFalse(viewModel.session.useKnowledgeBase)
        XCTAssertTrue(viewModel.session.isLocalDraft)
    }

    func testRenameSession_onDraft_updatesLocalTitleOnly() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let viewModel = ChatViewModel(
            session: KBSession.makeLocalDraft(),
            client: StubChatAPIClient(store: store),
            sessionCreator: StubKnowledgeBaseAPIClient(store: store)
        )

        try await viewModel.renameSession(to: "  Draft name  ")

        XCTAssertEqual(viewModel.session.title, "Draft name")
        XCTAssertTrue(viewModel.session.isLocalDraft)
        XCTAssertEqual(store.sessionsSnapshot().count, 0)
    }

    func testRenameSession_onServerSession_callsAPI() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let created = store.createSession(title: "Old")
        let viewModel = ChatViewModel(
            session: created,
            client: StubChatAPIClient(store: store),
            sessionCreator: StubKnowledgeBaseAPIClient(store: store)
        )

        try await viewModel.renameSession(to: "New title")

        XCTAssertEqual(viewModel.session.title, "New title")
        XCTAssertEqual(store.sessionsSnapshot().first?.title, "New title")
    }
}
