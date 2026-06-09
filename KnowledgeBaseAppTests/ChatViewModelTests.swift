import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class ChatViewModelTests: XCTestCase {
    private func makeSession(id: String = "test-session") -> KBSession {
        KBSession(id: id, title: "Test", messageCount: 0, updatedAt: nil)
    }

    private func emptyStoreWithSession() -> (InMemoryKBStore, String) {
        let store = InMemoryKBStore(demoSession: false)
        let session = store.createSession(title: "Test")
        return (store, session.id)
    }

    func testSend_setsWaitingImmediatelyAfterOptimisticAppend() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = SlowConnectStreamChatAPIClient(store: store, connectDelayNanoseconds: 500_000_000)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.draft = "hello"

        let sendTask = Task { await viewModel.send() }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.assistantReplyPhase, .waiting)
        XCTAssertEqual(viewModel.messages.count, 1)
        await sendTask.value
        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
    }

    func testSend_setsWaitingBeforeFirstStreamChunk() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        var client = StubChatAPIClient(store: store)
        client.streamInitialDelayNanoseconds = 300_000_000

        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.draft = "hello"

        let sendTask = Task { await viewModel.send() }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.assistantReplyPhase, .waiting)
        await sendTask.value
        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
        XCTAssertFalse(viewModel.messages.isEmpty)
    }

    func testSend_transitionsThroughStreamingToIdle() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.draft = "ping"

        await viewModel.send()

        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.messages.contains { $0.role == .user && $0.content == "ping" })
        XCTAssertTrue(viewModel.messages.contains { $0.role == .assistant })
    }

    func testSend_onError_resetsPhaseAndKeepsOptimisticUser() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = FailingStreamChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.draft = "fail"

        await viewModel.send()

        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertEqual(viewModel.messages.first?.content, "fail")
    }

    func testApplyExternalAssistantPhase_scrollsToBottomWhenActive() {
        let store = InMemoryKBStore()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(), client: client)

        viewModel.applyExternalAssistantPhase(.waiting)
        XCTAssertEqual(viewModel.assistantReplyPhase, .waiting)
        XCTAssertEqual(viewModel.scrollIntent, .scrollToBottom)

        viewModel.acknowledgeScrollIntent()
        viewModel.applyExternalAssistantPhase(.streaming(text: "voice"))
        XCTAssertEqual(viewModel.scrollIntent, .scrollToBottom)
    }

    func testReloadLatestWindow_clearsAssistantPhase() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.assistantReplyPhase = .finalizing(text: "partial")

        await viewModel.reloadLatestWindow()

        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
    }

    func testLoad_populatesInitialWindow() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        _ = try await client.sendTextMessage(sessionId: sessionId, text: "one", useKnowledgeBase: false)
        _ = try await client.sendTextMessage(sessionId: sessionId, text: "two", useKnowledgeBase: false)

        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.messages.count, 4)
        XCTAssertEqual(viewModel.totalCount, 4)
    }

    func testLoadOlder_prependsPageAndPreservesScrollIntent() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        for index in 1 ... 7 {
            _ = try await client.sendTextMessage(sessionId: sessionId, text: "msg \(index)", useKnowledgeBase: false)
        }

        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        await viewModel.load()
        let anchorId = viewModel.messages.first?.id
        XCTAssertNotNil(anchorId)
        XCTAssertTrue(viewModel.hasMoreOlder)

        await viewModel.loadOlder()

        XCTAssertFalse(viewModel.isLoadingOlder)
        XCTAssertEqual(viewModel.messages.count, 10)
        if case .preserve(let messageId) = viewModel.scrollIntent {
            XCTAssertEqual(messageId, anchorId)
        } else {
            XCTFail("Expected preserve scroll intent")
        }
    }

    func testSend_emptyDraft_isNoOp() async {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.draft = "   "

        await viewModel.send()

        XCTAssertEqual(viewModel.assistantReplyPhase, .idle)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testClearError() {
        let client = StubChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: makeSession(), client: client)
        viewModel.reportError("boom")
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadOlder_skipsWhenHasMoreOlderIsFalse() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        await viewModel.load()
        viewModel.hasMoreOlder = false
        let before = viewModel.messages.count

        await viewModel.loadOlder()

        XCTAssertEqual(viewModel.messages.count, before)
    }

    func testLoadOlder_skipsWhenAlreadyLoadingOlder() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        viewModel.isLoadingOlder = true

        await viewModel.loadOlder()

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testLoadOlder_skipsWhenInitialLoadInProgress() async {
        let client = StubChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: makeSession(), client: client)
        viewModel.isLoading = true
        viewModel.hasMoreOlder = true
        viewModel.messages = [
            KBMessage(id: "m1", role: .user, content: "x", createdAt: Date()),
        ]

        await viewModel.loadOlder()

        XCTAssertEqual(viewModel.messages.count, 1)
    }

    func testLoadOlder_skipsWhenNoAnchorMessage() async {
        let client = StubChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: makeSession(), client: client)
        viewModel.hasMoreOlder = true

        await viewModel.loadOlder()

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testApplyExternalAssistantPhase_idleDoesNotScroll() {
        let client = StubChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: makeSession(), client: client)
        viewModel.applyExternalAssistantPhase(.idle)
        XCTAssertEqual(viewModel.scrollIntent, .none)
    }

    func testAcknowledgeScrollIntent_clearsIntent() {
        let client = StubChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: makeSession(), client: client)
        viewModel.scrollIntent = .scrollToBottom
        viewModel.acknowledgeScrollIntent()
        XCTAssertEqual(viewModel.scrollIntent, .none)
    }

    func testLoad_onFetchError_setsErrorMessage() async {
        let client = FailingFetchChatAPIClient()
        let viewModel = ChatViewModel(session: makeSession(id: "missing"), client: client)
        await viewModel.load()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testReloadLatestWindow_onFetchError_setsErrorMessage() async {
        let client = FailingFetchChatAPIClient()
        let viewModel = ChatViewModel(session: makeSession(id: "missing"), client: client)
        await viewModel.reloadLatestWindow()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSendAttachment_reloadsThread() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await viewModel.sendAttachment(fileURL: url, filename: "test.txt", mimeType: "text/plain")

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertFalse(viewModel.messages.isEmpty)
    }

    func testLoadOlder_onFetchError_setsErrorMessage() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        for index in 1 ... 7 {
            _ = try await StubChatAPIClient(store: store).sendTextMessage(
                sessionId: sessionId,
                text: "msg \(index)",
                useKnowledgeBase: false
            )
        }
        let client = FailingOlderFetchChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: makeSession(id: sessionId), client: client)
        await viewModel.load()
        let countBefore = viewModel.messages.count

        await viewModel.loadOlder()

        XCTAssertEqual(viewModel.messages.count, countBefore)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

/// Defers returning the SSE stream (simulates waiting for HTTP headers from prod API).
private struct SlowConnectStreamChatAPIClient: ChatAPIClientProtocol {
    let store: InMemoryKBStore
    var connectDelayNanoseconds: UInt64 = 0

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        try await StubChatAPIClient(store: store).fetchMessagesPage(
            sessionId: sessionId,
            limit: limit,
            beforeMessageId: beforeMessageId
        )
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        try await StubChatAPIClient(store: store).sendTextMessage(
            sessionId: sessionId,
            text: text,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String { "" }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
        if connectDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: connectDelayNanoseconds)
        }
        return try await StubChatAPIClient(store: store).streamTextMessage(
            sessionId: sessionId,
            text: text,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await StubChatAPIClient(store: store).streamComposedMessage(
            sessionId: sessionId,
            draft: draft,
            useKnowledgeBase: useKnowledgeBase
        )
    }
}

/// Yields a stream that fails immediately after the user message is queued.
private struct FailingStreamChatAPIClient: ChatAPIClientProtocol {
    struct StreamError: Error, LocalizedError {
        var errorDescription: String? { "Stream failed" }
    }

    let store: InMemoryKBStore

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
    ) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String { "" }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: StreamError())
        }
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}

private struct FailingFetchChatAPIClient: ChatAPIClientProtocol {
    struct FetchError: Error, LocalizedError {
        var errorDescription: String? { "Fetch failed" }
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        throw FetchError()
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] { [] }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String { "" }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}

private struct FailingOlderFetchChatAPIClient: ChatAPIClientProtocol {
    let store: InMemoryKBStore

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        if beforeMessageId != nil {
            throw FailingFetchChatAPIClient.FetchError()
        }
        return try await StubChatAPIClient(store: store).fetchMessagesPage(
            sessionId: sessionId,
            limit: limit,
            beforeMessageId: beforeMessageId
        )
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        try await StubChatAPIClient(store: store).sendTextMessage(
            sessionId: sessionId,
            text: text,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String { "" }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
        try await StubChatAPIClient(store: store).streamTextMessage(
            sessionId: sessionId,
            text: text,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await StubChatAPIClient(store: store).streamComposedMessage(
            sessionId: sessionId,
            draft: draft,
            useKnowledgeBase: useKnowledgeBase
        )
    }
}
