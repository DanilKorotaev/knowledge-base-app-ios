import XCTest
@testable import KnowledgeBaseApp

final class PushNotificationPayloadTests: XCTestCase {
    func testParseSessionIdFromDeepLinkURL() {
        let url = URL(string: "knowledgebase://session/42")!
        XCTAssertEqual(PushNotificationService.parseSessionId(from: url), "42")
    }

    func testParseSessionIdFromUserInfo() {
        let info: [AnyHashable: Any] = ["session_id": "7", "type": "chat_reply_ready"]
        XCTAssertEqual(PushNotificationService.sessionId(from: info), "7")
    }

    func testIgnoresUnrelatedURL() {
        let url = URL(string: "knowledgebase://record")!
        XCTAssertNil(PushNotificationService.parseSessionId(from: url))
    }
}

@MainActor
final class ChatSessionFocusTrackerTests: XCTestCase {
    func testFocusedSessionId() {
        let tracker = ChatSessionFocusTracker.shared
        tracker.setFocusedSessionId("abc")
        XCTAssertEqual(tracker.focusedSessionId, "abc")
        tracker.setFocusedSessionId(nil)
        XCTAssertNil(tracker.focusedSessionId)
    }
}
