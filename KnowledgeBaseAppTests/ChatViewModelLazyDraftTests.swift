import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class ChatViewModelLazyDraftTests: XCTestCase {
    func testLoad_onLocalDraft_skipsNetworkAndStaysEmpty() async {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubChatAPIClient(store: store)
        let sessions = StubKnowledgeBaseAPIClient(store: store)
        let draft = KBSession.makeLocalDraft()
        let viewModel = ChatViewModel(
            session: draft,
            client: client,
            sessionCreator: sessions
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.session.isLocalDraft)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(store.sessionsSnapshot().count, 0)
    }

    func testSendComposed_promotesDraftOnceAndCreatesServerSession() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubChatAPIClient(store: store)
        let sessions = StubKnowledgeBaseAPIClient(store: store)
        let draft = KBSession.makeLocalDraft(useKnowledgeBase: true)
        let draftId = draft.id
        let viewModel = ChatViewModel(
            session: draft,
            client: client,
            sessionCreator: sessions
        )
        viewModel.draft = "First message for lazy create"

        await viewModel.sendComposed()

        XCTAssertFalse(viewModel.session.isLocalDraft)
        XCTAssertNotEqual(viewModel.session.id, draftId)
        XCTAssertEqual(store.sessionsSnapshot().count, 1)
        XCTAssertEqual(store.sessionsSnapshot().first?.id, viewModel.session.id)
        XCTAssertFalse(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testEnsureServerSession_isIdempotentUnderConcurrentCalls() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubChatAPIClient(store: store)
        let sessions = StubKnowledgeBaseAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: KBSession.makeLocalDraft(),
            client: client,
            sessionCreator: sessions
        )
        let draft = ChatComposerDraft(text: "concurrent")

        async let first: Void = viewModel.ensureServerSessionIfNeeded(using: draft)
        async let second: Void = viewModel.ensureServerSessionIfNeeded(using: draft)
        _ = try await (first, second)

        XCTAssertEqual(store.sessionsSnapshot().count, 1)
        XCTAssertFalse(viewModel.session.isLocalDraft)
    }

    func testSendComposed_withoutSessionCreator_setsErrorAndLeavesDraft() async {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: KBSession.makeLocalDraft(),
            client: client,
            sessionCreator: nil
        )
        viewModel.draft = "orphan"

        await viewModel.sendComposed()

        XCTAssertTrue(viewModel.session.isLocalDraft)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(store.sessionsSnapshot().count, 0)
        XCTAssertEqual(viewModel.draft, "orphan")
    }
}
