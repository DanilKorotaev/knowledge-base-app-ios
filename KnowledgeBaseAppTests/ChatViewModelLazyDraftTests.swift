@testable import KnowledgeBaseApp
import XCTest

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

    /// Regression: persist remaps voice into `draft:<uuid>/files/`, promote used to
    /// `clear` that folder before upload — first voice send then failed with a missing file.
    func testSendComposed_voiceAfterDraftPersist_keepsAudioAliveThroughPromote() async throws {
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("lazy-voice-promote-\(UUID().uuidString)", isDirectory: true)
        let draftStore = ComposerDraftStore(baseURL: storeRoot)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let audio = storeRoot.appendingPathComponent("source.m4a")
        try Data("voice-bytes".utf8).write(to: audio)

        let store = InMemoryKBStore(demoSession: false)
        let client = FileRequiringVoiceChatAPIClient(store: store)
        let sessions = StubKnowledgeBaseAPIClient(store: store)
        let draft = KBSession.makeLocalDraft()
        let draftId = draft.id
        let viewModel = ChatViewModel(
            session: draft,
            client: client,
            sessionCreator: sessions,
            composerDraftStore: draftStore
        )
        viewModel.composerDraft.voiceClips = [
            PendingVoiceClip(audioURL: audio, transcriptionSegment: "Начало фразы для заголовка")
        ]
        viewModel.composerDraft.appendTranscription("Начало фразы для заголовка")
        viewModel.persistComposerDraftNow()

        let remappedURL = try XCTUnwrap(viewModel.composerDraft.voiceClips.first?.audioURL)
        XCTAssertTrue(remappedURL.path.contains(draftId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? draftId))

        await viewModel.sendComposed()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.session.isLocalDraft)
        // Client required the file at upload time; after success the draft store is cleared.
        let uploadedURL = try XCTUnwrap(client.lastVoiceURL)
        XCTAssertFalse(uploadedURL.path.contains("draft:"))
        XCTAssertTrue(client.didReadVoiceBytes)
        XCTAssertEqual(store.sessionsSnapshot().count, 1)
        XCTAssertFalse(viewModel.messages.isEmpty)
    }
}

/// Like Stub, but fails the way production does when promote deleted draft-store audio.
@MainActor
private final class FileRequiringVoiceChatAPIClient: ChatAPIClientProtocol, @unchecked Sendable {
    let store: InMemoryKBStore
    private(set) var lastVoiceURL: URL?
    private(set) var didReadVoiceBytes = false

    init(store: InMemoryKBStore) {
        self.store = store
    }

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
        try await StubChatAPIClient(store: store).sendAttachment(
            sessionId: sessionId,
            fileURL: fileURL,
            filename: filename,
            mimeType: mimeType,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        try await StubChatAPIClient(store: store).transcribeVoiceRecording(audioFileURL: audioFileURL)
    }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        try await StubChatAPIClient(store: store).sendVoiceRecording(
            sessionId: sessionId,
            audioFileURL: audioFileURL,
            transcriptionHint: transcriptionHint,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func streamTextMessage(
        sessionId: String,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
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
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        lastVoiceURL = audioFileURL
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        _ = try Data(contentsOf: audioFileURL)
        didReadVoiceBytes = true
        return try await StubChatAPIClient(store: store).streamVoiceMessage(
            sessionId: sessionId,
            audioFileURL: audioFileURL,
            text: text,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        try await StubChatAPIClient(store: store).streamComposedMessage(
            sessionId: sessionId,
            draft: draft,
            useKnowledgeBase: useKnowledgeBase
        )
    }
}
