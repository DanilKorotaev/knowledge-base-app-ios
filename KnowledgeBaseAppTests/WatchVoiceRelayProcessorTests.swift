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
}

private struct RelayWatchChatAPIClient: ChatAPIClientProtocol {
    var transcription: String
    var streamReply: String = ""
    var streamChunks: [String]?

    func fetchMessagesPage(sessionId: String, limit: Int, beforeMessageId: String?) async throws -> KBMessagesPage {
        KBMessagesPage(messages: [], total: 0, hasMoreOlder: false)
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
        AsyncThrowingStream { continuation in
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
