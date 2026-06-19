import XCTest
@testable import KnowledgeBaseApp

final class ChatAPIClientTests: XCTestCase {
    private func emptyStoreWithSession() -> (InMemoryKBStore, String) {
        let store = InMemoryKBStore(demoSession: false)
        let session = store.createSession(title: "Test")
        return (store, session.id)
    }

    func testStubSendTrimsAndAppendsUserAndAssistant() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)

        let list = try await client.sendTextMessage(
            sessionId: sessionId,
            text: "  hello  ",
            useKnowledgeBase: true
        )

        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].role, .user)
        XCTAssertEqual(list[0].content, "hello")
        XCTAssertEqual(list[1].role, .assistant)
        XCTAssertTrue(list[1].content.contains("Stub reply"))
    }

    func testStubSendEmptyTextDoesNotAppend() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)

        let list = try await client.sendTextMessage(
            sessionId: sessionId,
            text: "   ",
            useKnowledgeBase: false
        )

        XCTAssertTrue(list.isEmpty)
    }

    func testFetchMessagesReturnsStoredThread() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        _ = try await client.sendTextMessage(sessionId: sessionId, text: "x", useKnowledgeBase: true)

        let page = try await client.fetchMessagesPage(sessionId: sessionId, limit: 20, beforeMessageId: nil)
        XCTAssertEqual(page.messages.count, 2)
        XCTAssertEqual(page.total, 2)
        XCTAssertFalse(page.hasMoreOlder)
    }

    func testSendAttachmentAppendsStubMessages() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-test-\(UUID().uuidString).txt")
        try "hello".write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let list = try await client.sendAttachment(
            sessionId: sessionId,
            fileURL: temp,
            filename: "note.txt",
            mimeType: "text/plain",
            useKnowledgeBase: true
        )

        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list[0].content.contains("note.txt"))
        XCTAssertEqual(list[1].role, .assistant)
    }

    func testStubStreamAccumulatesToFinalAssistantMessage() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let stream = try await client.streamTextMessage(
            sessionId: sessionId,
            text: "hello",
            useKnowledgeBase: true
        )
        var accumulated = ""
        for try await event in stream {
            if case .delta(let chunk) = event {
                accumulated += chunk
            }
        }
        let page = try await client.fetchMessagesPage(sessionId: sessionId, limit: 20, beforeMessageId: nil)
        XCTAssertEqual(page.messages.count, 2)
        XCTAssertEqual(page.messages[1].role, .assistant)
        XCTAssertEqual(page.messages[1].content, accumulated)
        XCTAssertTrue(accumulated.contains("Stub reply"))
    }

    func testStubStreamEmptyTextFinishesWithoutMessages() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let stream = try await client.streamTextMessage(
            sessionId: sessionId,
            text: "   ",
            useKnowledgeBase: false
        )
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0)
        let page = try await client.fetchMessagesPage(sessionId: sessionId, limit: 20, beforeMessageId: nil)
        XCTAssertTrue(page.messages.isEmpty)
    }

    func testStubFetchMessagesPageReturnsLatestSlice() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        for i in 1 ... 7 {
            _ = try await client.sendTextMessage(sessionId: sessionId, text: "msg \(i)", useKnowledgeBase: false)
        }

        let first = try await client.fetchMessagesPage(sessionId: sessionId, limit: 5, beforeMessageId: nil)
        XCTAssertEqual(first.messages.count, 5)
        XCTAssertEqual(first.total, 14)
        XCTAssertTrue(first.hasMoreOlder)
        XCTAssertTrue(first.messages.last?.content.contains("msg 7") ?? false)

        let oldestId = first.messages.first!.id
        let older = try await client.fetchMessagesPage(
            sessionId: sessionId,
            limit: 5,
            beforeMessageId: oldestId
        )
        XCTAssertEqual(older.messages.count, 5)
        XCTAssertTrue(older.hasMoreOlder)
        XCTAssertFalse(older.messages.contains(where: { $0.id == oldestId }))
    }

    func testTranscribeVoiceRecordingReturnsStubText() async throws {
        let (store, _) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-asr-\(UUID().uuidString).m4a")
        try Data([0, 1, 2]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let text = try await client.transcribeVoiceRecording(audioFileURL: temp)
        XCTAssertTrue(text.contains("Stub Whisper"))
    }

    func testSendVoiceRecordingAppendsStubMessages() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-voice-\(UUID().uuidString).m4a")
        try Data([0, 1]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let result = try await client.sendVoiceRecording(
            sessionId: sessionId,
            audioFileURL: temp,
            transcriptionHint: "hello voice",
            useKnowledgeBase: true
        )

        XCTAssertEqual(result.messages.count, 2)
        XCTAssertTrue(result.messages[0].content.contains("🎤"))
        XCTAssertTrue(result.messages[0].content.contains("hello voice"))
        XCTAssertTrue(result.messages[1].content.contains("Stub voice"))
        XCTAssertNil(result.transcription)
    }

    func testStubVoiceReturnsTranscriptionWhenHintEmpty() async throws {
        let (store, sessionId) = emptyStoreWithSession()
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-voice-empty-\(UUID().uuidString).m4a")
        try Data([0, 1]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let result = try await client.sendVoiceRecording(
            sessionId: sessionId,
            audioFileURL: temp,
            transcriptionHint: "   ",
            useKnowledgeBase: true
        )

        XCTAssertFalse(result.messages.isEmpty)
        XCTAssertTrue(result.transcription?.contains("Stub Whisper") ?? false)
    }
}
