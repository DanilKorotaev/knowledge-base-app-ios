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
}
