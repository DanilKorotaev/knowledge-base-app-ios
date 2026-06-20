import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class WatchVoiceRelayProcessorTests: XCTestCase {
    private func makeAudioFile(bytes: Int = 128) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relay-test-\(UUID().uuidString).m4a")
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    private func makeSessions(ids: [String] = ["125"]) -> [KBSession] {
        ids.map { KBSession(id: $0, title: "Session \($0)", messageCount: 0, updatedAt: nil) }
    }

    func testProcess_successWithHintedSession_stripsAnsi() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(
            transcription: "Привет с часов",
            streamReply: "Ответ ассистента\u{1B}[?25h"
        )

        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: "125",
            chatClient: client,
            sessionProvider: { self.makeSessions() }
        )

        XCTAssertTrue(preview.contains("Ответ"))
        XCTAssertFalse(preview.contains("[?25h"))
    }

    func testProcess_usesFallbackSessionWhenHintMissing() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(transcription: "ping", streamReply: "pong")
        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: nil,
            chatClient: client,
            sessionProvider: { self.makeSessions(ids: ["alpha", "beta"]) }
        )

        XCTAssertTrue(preview.contains("pong"))
    }

    func testProcess_ignoresEmptyHint() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(transcription: "ping", streamReply: "alpha-reply")
        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: "",
            chatClient: client,
            sessionProvider: { self.makeSessions(ids: ["alpha", "beta"]) }
        )

        XCTAssertTrue(preview.contains("alpha-reply"))
    }

    func testProcess_throwsWhenNoTargetSession() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(transcription: "ping", streamReply: "unused")

        do {
            _ = try await WatchVoiceRelayProcessor.process(
                audioURL: audioURL,
                hintedSessionID: "missing",
                chatClient: client,
                sessionProvider: { [] }
            )
            XCTFail("expected noTargetSession")
        } catch let error as WatchRelayError {
            guard case .noTargetSession = error else {
                return XCTFail("expected noTargetSession, got \(error)")
            }
            XCTAssertEqual(error.errorDescription, "Set a voice default session on iPhone.")
        }
    }

    func testProcess_throwsWhenTranscriptionEmpty() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(transcription: "   \n", streamReply: "unused")

        do {
            _ = try await WatchVoiceRelayProcessor.process(
                audioURL: audioURL,
                hintedSessionID: "125",
                chatClient: client,
                sessionProvider: { self.makeSessions() }
            )
            XCTFail("expected emptyTranscription")
        } catch let error as WatchRelayError {
            guard case .emptyTranscription = error else {
                return XCTFail("expected emptyTranscription, got \(error)")
            }
            XCTAssertEqual(error.errorDescription, "Could not transcribe the recording.")
        }
    }

    func testProcess_truncatesPreviewToLimit() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let longReply = String(repeating: "x", count: 250)
        let client = RelayWatchChatAPIClient(transcription: "go", streamReply: longReply)

        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: "125",
            chatClient: client,
            sessionProvider: { self.makeSessions() }
        )

        XCTAssertEqual(preview.count, 200)
    }

    func testProcess_aggregatesStreamingChunks() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(
            transcription: "question",
            streamChunks: ["Hello", " ", "watch"]
        )

        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: "125",
            chatClient: client,
            sessionProvider: { self.makeSessions() }
        )

        XCTAssertEqual(preview, "Hello watch")
    }

    func testProcess_recoversViaPollWhenStreamFails() async throws {
        let audioURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let client = RelayWatchChatAPIClient(
            transcription: "Еще один тест",
            streamShouldFail: true,
            polledAssistantReply: "Принято. Можем прогнать следующий шаг теста."
        )

        let preview = try await WatchVoiceRelayProcessor.process(
            audioURL: audioURL,
            hintedSessionID: "125",
            chatClient: client,
            sessionProvider: { self.makeSessions() }
        )

        XCTAssertEqual(preview, "Принято. Можем прогнать следующий шаг теста.")
    }
}

private final class RelayWatchChatAPIClient: ChatAPIClientProtocol {
    var transcription: String
    var streamReply: String = ""
    var streamChunks: [String]?
    var streamShouldFail = false
    var polledAssistantReply: String?
    private var fetchCount = 0

    init(
        transcription: String,
        streamReply: String = "",
        streamChunks: [String]? = nil,
        streamShouldFail: Bool = false,
        polledAssistantReply: String? = nil
    ) {
        self.transcription = transcription
        self.streamReply = streamReply
        self.streamChunks = streamChunks
        self.streamShouldFail = streamShouldFail
        self.polledAssistantReply = polledAssistantReply
    }

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        fetchCount += 1
        if fetchCount == 1 {
            return KBMessagesPage(
                messages: [KBMessage(id: "802", role: .assistant, content: "Previous reply", createdAt: nil)],
                total: 1,
                hasMoreOlder: false
            )
        }
        if let polledAssistantReply {
            return KBMessagesPage(
                messages: [
                    KBMessage(id: "803", role: .user, content: transcription, createdAt: nil),
                    KBMessage(id: "804", role: .assistant, content: polledAssistantReply, createdAt: nil),
                ],
                total: 2,
                hasMoreOlder: false
            )
        }
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

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        transcription
    }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        VoiceRecordingSendResult(messages: [], transcription: nil)
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
        if streamShouldFail {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: URLError(.networkConnectionLost))
            }
        }
        return AsyncThrowingStream { continuation in
            let chunks = streamChunks ?? [streamReply]
            for chunk in chunks {
                continuation.yield(.delta(chunk))
            }
            continuation.finish()
        }
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
