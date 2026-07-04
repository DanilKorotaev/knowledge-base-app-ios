import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class ChatViewModelVoiceRetryTests: XCTestCase {
    func testTranscriptionFailureKeepsPendingCaptureAndAudioFile() async throws {
        let store = InMemoryKBStore(demoSession: false)
        _ = store.createSession(title: "Chat")
        let session = KBSession(id: "1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-retry-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)

        let client = FailingTranscribeThenSuccessChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: session, client: client)

        await viewModel.enqueueVoiceRecording(audioURL: source)

        XCTAssertEqual(viewModel.pendingVoiceCaptures.count, 1)
        if case .failed = viewModel.pendingVoiceCaptures[0].state {
            // expected
        } else {
            XCTFail("Expected failed pending capture")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewModel.pendingVoiceCaptures[0].audioURL.path))
        XCTAssertTrue(viewModel.composerDraft.voiceClips.isEmpty)

        await viewModel.retryPendingVoiceCaptureTranscription(id: viewModel.pendingVoiceCaptures[0].id)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertEqual(viewModel.composerDraft.voiceClips.count, 1)
        XCTAssertFalse(viewModel.composerDraft.trimmedText.isEmpty)
    }

    func testEnqueueVoiceRecordingAcceptsAlreadyPersistedURL() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-handoff-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)
        try FileManager.default.removeItem(at: source)

        let client = SuccessTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: session, client: client)

        await viewModel.enqueueVoiceRecording(audioURL: persisted)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertEqual(viewModel.composerDraft.voiceClips.count, 1)
        XCTAssertFalse(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDiscardPendingVoiceCaptureDeletesStoredAudio() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-discard-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)

        let client = AlwaysFailingTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(session: session, client: client)

        await viewModel.enqueueVoiceRecording(audioURL: source)
        let captureID = try XCTUnwrap(viewModel.pendingVoiceCaptures.first?.id)
        let audioURL = try XCTUnwrap(viewModel.pendingVoiceCaptures.first?.audioURL)

        viewModel.discardPendingVoiceCapture(id: captureID)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }
}

@MainActor
private final class SuccessTranscribeChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
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
        "Транскрипция после handoff"
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

@MainActor
private final class FailingTranscribeThenSuccessChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore
    private var attempts = 0

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
        attempts += 1
        if attempts == 1 {
            throw URLError(.timedOut)
        }
        return "Привет из повторной транскрибации"
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

@MainActor
private final class AlwaysFailingTranscribeChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
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
        throw URLError(.notConnectedToInternet)
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

final class VoicePipelineErrorMessageTests: XCTestCase {
    func testTimeoutStatusCodeIsShort() {
        let message = VoicePipelineErrorMessage.forTranscription(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 504, apiMessage: nil)
        )
        XCTAssertEqual(message, "Таймаут сервера (504).")
    }

    func testURLErrorNotConnectedIsShort() {
        let message = VoicePipelineErrorMessage.forTranscription(URLError(.notConnectedToInternet))
        XCTAssertEqual(message, "Нет подключения к интернету.")
    }

    func testDoesNotIncludeRetryInstructions() {
        let message = VoicePipelineErrorMessage.forTranscription(URLError(.notConnectedToInternet))
        XCTAssertFalse(message.contains("Повторить"))
        XCTAssertFalse(message.contains("VPN"))
    }
}
