import XCTest
@testable import KnowledgeBaseApp

final class ComposerDraftStoreTests: XCTestCase {
    private var store: ComposerDraftStore!
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-draft-store-\(UUID().uuidString)", isDirectory: true)
        store = ComposerDraftStore(baseURL: tempRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testSaveAndLoadRoundTrip() throws {
        let sessionId = "session-42"
        let audio = tempRoot.appendingPathComponent("voice.m4a")
        try Data("audio".utf8).write(to: audio)

        var draft = ChatComposerDraft()
        draft.text = "Черновик с голосом"
        draft.voiceClips = [
            PendingVoiceClip(audioURL: audio, transcriptionSegment: "la la la")
        ]
        let pending = [
            PendingVoiceCapture(
                audioURL: audio,
                state: .failed(message: "Нет подключения к интернету.")
            )
        ]

        let saved = try XCTUnwrap(store.save(sessionId: sessionId, draft: draft, pendingVoiceCaptures: pending))
        let loaded = try XCTUnwrap(store.load(sessionId: sessionId))

        XCTAssertEqual(loaded.draft.text, saved.draft.text)
        XCTAssertEqual(loaded.draft.voiceClips.count, 1)
        XCTAssertEqual(loaded.pendingVoiceCaptures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.draft.voiceClips[0].audioURL.path))
    }

    func testClearRemovesStoredDraft() throws {
        let sessionId = "session-clear"
        var draft = ChatComposerDraft()
        draft.text = "temp"

        _ = store.save(sessionId: sessionId, draft: draft, pendingVoiceCaptures: [])
        XCTAssertNotNil(store.load(sessionId: sessionId))

        store.clear(sessionId: sessionId)
        XCTAssertNil(store.load(sessionId: sessionId))
    }

    func testEmptyDraftClearsStore() {
        let sessionId = "session-empty"
        var draft = ChatComposerDraft()
        draft.text = "x"
        _ = store.save(sessionId: sessionId, draft: draft, pendingVoiceCaptures: [])

        draft.text = ""
        XCTAssertNil(store.save(sessionId: sessionId, draft: draft, pendingVoiceCaptures: []))
        XCTAssertNil(store.load(sessionId: sessionId))
    }
}

@MainActor
final class ChatViewModelComposerDraftTests: XCTestCase {
    func testRestoresDraftOnInit() throws {
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-draft-vm-\(UUID().uuidString)", isDirectory: true)
        let draftStore = ComposerDraftStore(baseURL: storeRoot)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let session = KBSession(id: "draft-session", title: "Chat", messageCount: 0, updatedAt: nil)
        var draft = ChatComposerDraft()
        draft.text = "Несохранённое сообщение"
        _ = draftStore.save(sessionId: session.id, draft: draft, pendingVoiceCaptures: [])

        let client = InMemoryChatAPIClient(store: InMemoryKBStore(demoSession: false))
        let viewModel = ChatViewModel(session: session, client: client, composerDraftStore: draftStore)

        XCTAssertEqual(viewModel.composerDraft.text, "Несохранённое сообщение")
    }

    func testClearsDraftAfterSuccessfulSend() async throws {
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-draft-send-\(UUID().uuidString)", isDirectory: true)
        let draftStore = ComposerDraftStore(baseURL: storeRoot)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let kbStore = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "send-session", title: "Chat", messageCount: 0, updatedAt: nil)
        let client = InMemoryChatAPIClient(store: kbStore)
        let viewModel = ChatViewModel(session: session, client: client, composerDraftStore: draftStore)
        viewModel.composerDraft.text = "Отправим и очистим"
        viewModel.persistComposerDraftNow()

        await viewModel.sendComposed()

        XCTAssertTrue(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertNil(draftStore.load(sessionId: session.id))
    }

    func testClearsComposerImmediatelyWhileReplyStreams() async throws {
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-draft-inflight-\(UUID().uuidString)", isDirectory: true)
        let draftStore = ComposerDraftStore(baseURL: storeRoot)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let audio = storeRoot.appendingPathComponent("voice.m4a")
        try Data("audio".utf8).write(to: audio)

        let kbStore = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "inflight-session", title: "Chat", messageCount: 0, updatedAt: nil)
        let client = SlowStreamChatAPIClient(store: kbStore, delayNanoseconds: 500_000_000)
        let viewModel = ChatViewModel(session: session, client: client, composerDraftStore: draftStore)
        viewModel.composerDraft.voiceClips = [
            PendingVoiceClip(audioURL: audio, transcriptionSegment: "Проверка черновика")
        ]
        viewModel.composerDraft.appendTranscription("Проверка черновика")
        viewModel.persistComposerDraftNow()

        let sendTask = Task { await viewModel.sendComposed() }
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(viewModel.composerDraft.voiceClips.isEmpty)
        XCTAssertTrue(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertNotNil(draftStore.load(sessionId: session.id))
        XCTAssertTrue(viewModel.assistantReplyPhase.showsPlaceholder)

        await sendTask.value
        XCTAssertTrue(viewModel.composerDraft.voiceClips.isEmpty)
    }

    func testFailedSendKeepsDraftStoreFilesForRetry() async throws {
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-draft-fail-\(UUID().uuidString)", isDirectory: true)
        let draftStore = ComposerDraftStore(baseURL: storeRoot)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let audio = storeRoot.appendingPathComponent("voice.m4a")
        try Data("audio".utf8).write(to: audio)

        let kbStore = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "fail-session", title: "Chat", messageCount: 0, updatedAt: nil)
        let client = FailingStreamChatAPIClient(store: kbStore)
        let viewModel = ChatViewModel(session: session, client: client, composerDraftStore: draftStore)
        viewModel.composerDraft.voiceClips = [
            PendingVoiceClip(audioURL: audio, transcriptionSegment: "retry me")
        ]
        viewModel.composerDraft.appendTranscription("retry me")
        viewModel.persistComposerDraftNow()

        await viewModel.sendComposed()

        let loaded = try XCTUnwrap(draftStore.load(sessionId: session.id))
        XCTAssertEqual(loaded.draft.voiceClips.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.draft.voiceClips[0].audioURL.path))
        XCTAssertTrue(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertTrue(viewModel.composerDraft.voiceClips.isEmpty)
        XCTAssertNotNil(viewModel.pendingSendRetry)
        // Optimistic bubble stays so Retry has an anchor.
        XCTAssertTrue(viewModel.messages.contains { $0.id.hasPrefix("kb-optimistic-") })
    }
}

@MainActor
private final class FailingStreamChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore

    init(store: InMemoryKBStore) {
        self.store = store
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        KBMessagesPage(messages: store.messages(for: sessionId), total: 0, hasMoreOlder: false)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func sendAttachment(sessionId: String, fileURL: URL, filename: String, mimeType: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        "ok"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: URLError(.notConnectedToInternet))
        }
    }

    func streamVoiceMessage(sessionId: String, audioFileURL: URL, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(sessionId: String, draft: ChatComposerDraft, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}

@MainActor
private final class SlowStreamChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore
    let delayNanoseconds: UInt64

    init(store: InMemoryKBStore, delayNanoseconds: UInt64) {
        self.store = store
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        KBMessagesPage(messages: store.messages(for: sessionId), total: 0, hasMoreOlder: false)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func sendAttachment(sessionId: String, fileURL: URL, filename: String, mimeType: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        "ok"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                continuation.finish()
            }
        }
    }

    func streamVoiceMessage(sessionId: String, audioFileURL: URL, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(sessionId: String, draft: ChatComposerDraft, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}

@MainActor
private final class InMemoryChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore

    init(store: InMemoryKBStore) {
        self.store = store
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        KBMessagesPage(messages: store.messages(for: sessionId), total: 0, hasMoreOlder: false)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func sendAttachment(sessionId: String, fileURL: URL, filename: String, mimeType: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        []
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        "ok"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func streamVoiceMessage(sessionId: String, audioFileURL: URL, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: text, useKnowledgeBase: useKnowledgeBase)
    }

    func streamComposedMessage(sessionId: String, draft: ChatComposerDraft, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await streamTextMessage(sessionId: sessionId, text: draft.trimmedText, useKnowledgeBase: useKnowledgeBase)
    }
}
