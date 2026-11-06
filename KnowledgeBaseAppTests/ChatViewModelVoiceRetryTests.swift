@testable import KnowledgeBaseApp
import XCTest

@MainActor
final class ChatViewModelVoiceRetryTests: XCTestCase {
    private var draftStoreRoot: URL!
    private var draftStore: ComposerDraftStore!

    override func setUpWithError() throws {
        draftStoreRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-retry-drafts-\(UUID().uuidString)", isDirectory: true)
        draftStore = ComposerDraftStore(baseURL: draftStoreRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: draftStoreRoot)
    }

    func testTranscriptionFailureKeepsPendingCaptureAndAudioFile() async throws {
        let store = InMemoryKBStore(demoSession: false)
        _ = store.createSession(title: "Chat")
        let session = KBSession(id: "voice-retry-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-retry-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)

        let client = FailingTranscribeThenSuccessChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )

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

    func testTransientTimeoutAutoRetriesWithoutManualRetry() async throws {
        let store = InMemoryKBStore(demoSession: false)
        _ = store.createSession(title: "Chat")
        let session = KBSession(id: "voice-auto-retry-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-auto-retry-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)

        let client = TransientThenSuccessTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )

        await viewModel.enqueueVoiceRecording(audioURL: source)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertEqual(viewModel.composerDraft.voiceClips.count, 1)
        XCTAssertEqual(client.attempts, 2)
        XCTAssertFalse(viewModel.composerDraft.trimmedText.isEmpty)
    }

    func testEnqueueVoiceRecordingAcceptsAlreadyPersistedURL() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "voice-handoff-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-handoff-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)
        try FileManager.default.removeItem(at: source)

        let client = SuccessTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )

        await viewModel.enqueueVoiceRecording(audioURL: persisted)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertEqual(viewModel.composerDraft.voiceClips.count, 1)
        XCTAssertFalse(viewModel.composerDraft.trimmedText.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDiscardPendingVoiceCaptureDeletesStoredAudio() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "voice-discard-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-discard-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)

        let client = AlwaysFailingTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )

        await viewModel.enqueueVoiceRecording(audioURL: source)
        let captureID = try XCTUnwrap(viewModel.pendingVoiceCaptures.first?.id)
        let audioURL = try XCTUnwrap(viewModel.pendingVoiceCaptures.first?.audioURL)

        viewModel.discardPendingVoiceCapture(id: captureID)

        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    /// Regression: SwiftUI re-creates throwaway ChatViewModels; init must not start transcription.
    func testInitDoesNotResumeInterruptedTranscription() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "voice-resume-init-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-resume-init-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)

        let capture = PendingVoiceCapture(audioURL: persisted, state: .transcribing)
        _ = draftStore.save(
            sessionId: session.id,
            draft: ChatComposerDraft(),
            pendingVoiceCaptures: [capture]
        )

        let client = CountingTranscribeChatAPIClient(store: store)
        _ = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )
        // Give any accidental Task a chance to schedule.
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(client.transcribeCallCount, 0)
    }

    func testLoadResumesInterruptedTranscriptionOnceAcrossRepeatedLoads() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "voice-resume-load-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-resume-load-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)

        let capture = PendingVoiceCapture(audioURL: persisted, state: .transcribing)
        _ = draftStore.save(
            sessionId: session.id,
            draft: ChatComposerDraft(),
            pendingVoiceCaptures: [capture]
        )

        let client = CountingTranscribeChatAPIClient(store: store)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )
        XCTAssertEqual(viewModel.pendingVoiceCaptures.count, 1)

        await viewModel.load()
        await viewModel.load()
        // Resume spawns a Task; wait until transcription finishes.
        for _ in 0..<40 where client.transcribeCallCount == 0 || !viewModel.pendingVoiceCaptures.isEmpty {
            try await Task.sleep(for: .milliseconds(25))
        }

        XCTAssertEqual(client.transcribeCallCount, 1)
        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
        XCTAssertEqual(viewModel.composerDraft.voiceClips.count, 1)
    }

    func testTranscribePendingVoiceCaptureIsSingleFlight() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let session = KBSession(id: "voice-single-flight-1", title: "Chat", messageCount: 0, updatedAt: nil)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-single-flight-\(UUID().uuidString).m4a")
        try Data("voice-bytes".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)

        let client = SlowCountingTranscribeChatAPIClient(store: store, delayNanoseconds: 80_000_000)
        let viewModel = ChatViewModel(
            session: session,
            client: client,
            composerDraftStore: draftStore
        )
        let capture = PendingVoiceCapture(audioURL: persisted, state: .transcribing)
        viewModel.pendingVoiceCaptures = [capture]

        async let first: Void = viewModel.transcribePendingVoiceCapture(id: capture.id)
        async let second: Void = viewModel.transcribePendingVoiceCapture(id: capture.id)
        _ = await (first, second)

        XCTAssertEqual(client.transcribeCallCount, 1)
        XCTAssertTrue(viewModel.pendingVoiceCaptures.isEmpty)
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

    func transcribeVoiceRecording(audioFileURL: URL, clientTranscriptionId: String?) async throws -> String {
        "Транскрипция после handoff"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
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

    func transcribeVoiceRecording(audioFileURL: URL, clientTranscriptionId: String?) async throws -> String {
        attempts += 1
        if attempts == 1 {
            // Non-transient: auto-retry must not swallow this before the manual Retry UI.
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: 422, apiMessage: nil)
        }
        return "Привет из повторной транскрибации"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
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

@MainActor
private final class CountingTranscribeChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore
    private(set) var transcribeCallCount = 0

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

    func transcribeVoiceRecording(audioFileURL: URL, clientTranscriptionId: String?) async throws -> String {
        transcribeCallCount += 1
        return "Возобновлённая транскрипция"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
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

@MainActor
private final class SlowCountingTranscribeChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore
    let delayNanoseconds: UInt64
    private(set) var transcribeCallCount = 0

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

    func transcribeVoiceRecording(audioFileURL: URL, clientTranscriptionId: String?) async throws -> String {
        transcribeCallCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return "Single-flight transcription"
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
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

    func transcribeVoiceRecording(audioFileURL: URL, clientTranscriptionId: String?) async throws -> String {
        throw URLError(.notConnectedToInternet)
    }

    func sendVoiceRecording(sessionId: String, audioFileURL: URL, transcriptionHint: String, useKnowledgeBase: Bool) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: transcriptionHint)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
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
