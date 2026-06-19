import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class ChatViewModelOfflineCacheTests: XCTestCase {
    private var cacheDir: URL!

    override func setUp() {
        super.setUp()
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-vm-cache-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDir)
        super.tearDown()
    }

    func testLoadShowsCachedMessagesBeforeNetwork() async throws {
        let sessionId = "offline-session"
        let cache = FileOfflineCacheStore(baseURL: cacheDir)
        let cached = [
            KBMessage(id: "cached-1", role: .user, content: "offline", createdAt: Date()),
            KBMessage(id: "cached-2", role: .assistant, content: "reply", createdAt: Date()),
        ]
        cache.saveWindow(
            sessionId: sessionId,
            page: KBMessagesPage(messages: cached, total: 2, hasMoreOlder: false)
        )

        let client = DelayedFetchChatAPIClient(delayNanoseconds: 400_000_000)
        let viewModel = ChatViewModel(
            session: KBSession(id: sessionId, title: "Test", messageCount: 2, updatedAt: Date()),
            client: client,
            messageCache: cache
        )

        let loadTask = Task { await viewModel.load() }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.messages.map(\.id), ["cached-1", "cached-2"])
        XCTAssertFalse(viewModel.isLoading)
        await loadTask.value
    }

    func testLoadOlderWhenOfflineDoesNotSetErrorMessage() async throws {
        let sessionId = "offline-pagination"
        let cache = FileOfflineCacheStore(baseURL: cacheDir)
        let cached = (1 ... 4).map { index in
            KBMessage(id: "m\(index)", role: .user, content: "msg \(index)", createdAt: Date())
        } + [
            KBMessage(id: "m5", role: .assistant, content: "reply", createdAt: Date()),
        ]
        cache.saveWindow(
            sessionId: sessionId,
            page: KBMessagesPage(messages: cached, total: 48, hasMoreOlder: true)
        )

        let client = OfflineThrowingChatAPIClient()
        let viewModel = ChatViewModel(
            session: KBSession(id: sessionId, title: "Test", messageCount: 48, updatedAt: Date()),
            client: client,
            messageCache: cache
        )
        await viewModel.load()
        NetworkPathMonitor.shared.setOnlineForTesting(false)
        defer { NetworkPathMonitor.shared.setOnlineForTesting(true) }

        await viewModel.loadOlder()

        XCTAssertNil(viewModel.errorMessage)
        if case .offline = viewModel.syncStatus {
            // expected
        } else {
            XCTFail("Expected offline sync status, got \(viewModel.syncStatus)")
        }
    }

    func testRefreshFromNetworkWithCacheWhenOfflineUsesOfflineStatusNotError() async throws {
        let sessionId = "offline-refresh"
        let cache = FileOfflineCacheStore(baseURL: cacheDir)
        cache.saveWindow(
            sessionId: sessionId,
            page: KBMessagesPage(
                messages: [
                    KBMessage(id: "c1", role: .user, content: "cached", createdAt: Date()),
                    KBMessage(id: "c2", role: .assistant, content: "reply", createdAt: Date()),
                ],
                total: 2,
                hasMoreOlder: false
            )
        )

        let viewModel = ChatViewModel(
            session: KBSession(id: sessionId, title: "Test", messageCount: 2, updatedAt: Date()),
            client: StubChatAPIClient(store: InMemoryKBStore(demoSession: false)),
            messageCache: cache
        )
        NetworkPathMonitor.shared.setOnlineForTesting(false)
        defer { NetworkPathMonitor.shared.setOnlineForTesting(true) }

        await viewModel.load()
        await viewModel.refresh()

        XCTAssertFalse(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        if case .offline = viewModel.syncStatus {
            // expected
        } else {
            XCTFail("Expected offline sync status, got \(viewModel.syncStatus)")
        }
    }
}

private final class OfflineThrowingChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        throw URLError(.notConnectedToInternet)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] { [] }
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
        AsyncThrowingStream { $0.finish() }
    }
    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private final class DelayedFetchChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return KBMessagesPage(messages: [], total: 0, hasMoreOlder: false)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] { [] }
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
        AsyncThrowingStream { $0.finish() }
    }
    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
