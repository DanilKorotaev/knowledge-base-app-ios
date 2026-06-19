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
