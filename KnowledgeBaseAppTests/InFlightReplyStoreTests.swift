import XCTest
@testable import KnowledgeBaseApp

final class InFlightReplyStoreTests: XCTestCase {
    private var storage: UserDefaults!
    private var previousShared: UserDefaultsServiceDescription!
    private var store: InFlightReplyStore!
    private var suiteName: String!

    override func setUpWithError() throws {
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        storage = isolated.storage
        suiteName = isolated.suiteName
        previousShared = UserDefaultsService.shared
        UserDefaultsService.shared = UserDefaultsService(storage: storage)
        store = InFlightReplyStore(maxAge: 60 * 30)
    }

    override func tearDownWithError() throws {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
    }

    func testSaveLoadUpdateAndClear() {
        store.save(InFlightReplyState(sessionId: "s1", startedAt: Date(), partialText: nil))
        XCTAssertNotNil(store.load(sessionId: "s1"))

        store.updatePartial(sessionId: "s1", text: "Hello")
        XCTAssertEqual(store.load(sessionId: "s1")?.partialText, "Hello")

        store.clear(sessionId: "s1")
        XCTAssertNil(store.load(sessionId: "s1"))
    }

    func testExpiredStateIsDropped() {
        let old = InFlightReplyState(
            sessionId: "old",
            startedAt: Date().addingTimeInterval(-60 * 60),
            partialText: "stale"
        )
        store.save(old)
        XCTAssertNil(store.load(sessionId: "old"))
    }
}

final class StreamInterruptionClassifierTests: XCTestCase {
    func testNetworkErrorsAreResumable() {
        XCTAssertTrue(StreamInterruptionClassifier.isResumable(URLError(.networkConnectionLost)))
        XCTAssertTrue(StreamInterruptionClassifier.isResumable(URLError(.timedOut)))
        XCTAssertTrue(StreamInterruptionClassifier.isResumable(URLError(.cancelled)))
        XCTAssertTrue(StreamInterruptionClassifier.isResumable(CancellationError()))
    }

    func testGenericErrorsAreNotResumable() {
        struct Boom: Error {}
        XCTAssertFalse(StreamInterruptionClassifier.isResumable(Boom()))
        XCTAssertFalse(StreamInterruptionClassifier.isResumable(URLError(.badServerResponse)))
        // Hard connectivity failures before the request is in flight — keep draft for retry.
        XCTAssertFalse(StreamInterruptionClassifier.isResumable(URLError(.notConnectedToInternet)))
        XCTAssertFalse(StreamInterruptionClassifier.isResumable(URLError(.cannotConnectToHost)))
    }
}

@MainActor
final class ChatViewModelInFlightResumeTests: XCTestCase {
    private final class MemoryInFlightStore: InFlightReplyStoreProtocol, @unchecked Sendable {
        var map: [String: InFlightReplyState] = [:]

        func load(sessionId: String) -> InFlightReplyState? { map[sessionId] }
        func save(_ state: InFlightReplyState) { map[state.sessionId] = state }
        func updatePartial(sessionId: String, text: String) {
            guard var state = map[sessionId] else { return }
            state.partialText = text
            map[sessionId] = state
        }
        func clear(sessionId: String) { map.removeValue(forKey: sessionId) }
    }

    private func makeSession(id: String) -> KBSession {
        KBSession(id: id, title: "Test", messageCount: 0, updatedAt: nil)
    }

    func testNetworkDropDuringStreamDoesNotShowErrorAndKeepsWaiting() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = store.createSession(title: "Chat")
        store.replaceMessages(
            [
                KBMessage(id: "u1", role: .user, content: "hello", createdAt: Date())
            ],
            sessionId: session.id
        )

        let client = DropAfterPartialStreamChatAPIClient(store: store)
        let inFlight = MemoryInFlightStore()
        let viewModel = ChatViewModel(
            session: makeSession(id: session.id),
            client: client,
            inFlightReplyStore: inFlight
        )
        viewModel.replyPollMaxAttempts = 2
        viewModel.replyPollIntervalNanoseconds = 0
        viewModel.draft = "hello"

        await viewModel.send()
        // Let the background resume Task finish its short poll.
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.assistantReplyPhase.showsPlaceholder
                || viewModel.messages.last?.role == .user
        )
        XCTAssertTrue(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertEqual(inFlight.load(sessionId: session.id)?.partialText, "partial")
    }

    func testInitRestoresStreamingUIFromInFlightMarker() {
        let store = InMemoryKBStore(demoSession: false)
        let session = store.createSession(title: "Chat")
        let inFlight = MemoryInFlightStore()
        inFlight.save(
            InFlightReplyState(sessionId: session.id, startedAt: Date(), partialText: "cached chunk")
        )

        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: makeSession(id: session.id),
            client: client,
            inFlightReplyStore: inFlight
        )

        XCTAssertEqual(viewModel.assistantReplyPhase, .streaming(text: "cached chunk"))
        XCTAssertNotNil(inFlight.load(sessionId: session.id))
    }
}

@MainActor
private final class DropAfterPartialStreamChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore

    init(store: InMemoryKBStore) {
        self.store = store
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        let messages = store.messages(for: sessionId)
        return KBMessagesPage(messages: messages, total: messages.count, hasMoreOlder: false)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        store.messages(for: sessionId)
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] { [] }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String { "" }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
    }

    func streamTextMessage(
        sessionId: String,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.delta("partial"))
            continuation.finish(throwing: URLError(.networkConnectionLost))
        }
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}
