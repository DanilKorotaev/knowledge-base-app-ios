import XCTest
@testable import KnowledgeBaseApp

final class ChatAPIClientTests: XCTestCase {
    func testStubSendTrimsAndAppendsUserAndAssistant() async throws {
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)

        let list = try await client.sendTextMessage(
            sessionId: "demo-session",
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
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)

        let list = try await client.sendTextMessage(
            sessionId: "demo-session",
            text: "   ",
            useKnowledgeBase: false
        )

        XCTAssertTrue(list.isEmpty)
    }

    func testFetchMessagesReturnsStoredThread() async throws {
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        _ = try await client.sendTextMessage(sessionId: "demo-session", text: "x", useKnowledgeBase: true)

        let fetched = try await client.fetchMessages(sessionId: "demo-session")
        XCTAssertEqual(fetched.count, 2)
    }

    func testSendAttachmentAppendsStubMessages() async throws {
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-test-\(UUID().uuidString).txt")
        try "hello".write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let list = try await client.sendAttachment(
            sessionId: "demo-session",
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
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        let stream = try await client.streamTextMessage(
            sessionId: "demo-session",
            text: "hello",
            useKnowledgeBase: true
        )
        var accumulated = ""
        for try await chunk in stream {
            accumulated += chunk
        }
        let list = try await client.fetchMessages(sessionId: "demo-session")
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[1].role, .assistant)
        XCTAssertEqual(list[1].content, accumulated)
        XCTAssertTrue(accumulated.contains("Stub reply"))
    }

    func testStubStreamEmptyTextFinishesWithoutMessages() async throws {
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        let stream = try await client.streamTextMessage(
            sessionId: "demo-session",
            text: "   ",
            useKnowledgeBase: false
        )
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0)
        let list = try await client.fetchMessages(sessionId: "demo-session")
        XCTAssertTrue(list.isEmpty)
    }

    func testSendVoiceRecordingAppendsStubMessages() async throws {
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-voice-\(UUID().uuidString).m4a")
        try Data([0, 1]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let result = try await client.sendVoiceRecording(
            sessionId: "demo-session",
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
        let store = InMemoryKBStore(demoSession: true)
        let client = StubChatAPIClient(store: store)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kb-voice-empty-\(UUID().uuidString).m4a")
        try Data([0, 1]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let result = try await client.sendVoiceRecording(
            sessionId: "demo-session",
            audioFileURL: temp,
            transcriptionHint: "   ",
            useKnowledgeBase: true
        )

        XCTAssertFalse(result.messages.isEmpty)
        XCTAssertTrue(result.transcription?.contains("Stub Whisper") ?? false)
    }
}
