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

    func testPayloadFormatterSerializesCustomFieldsAndAps() {
        let userInfo: [AnyHashable: Any] = [
            "type": "chat_reply_ready",
            "session_id": "125",
            "message_id": "690",
            "aps": [
                "alert": ["title": "Session 125", "body": "Preview"],
                "sound": "default",
                "thread-id": "125",
            ] as [String: Any],
        ]
        let json = PushPayloadFormatter.json(userInfo)
        XCTAssertTrue(json.contains("chat_reply_ready"))
        XCTAssertTrue(json.contains("125"))
        XCTAssertTrue(json.contains("690"))
        XCTAssertTrue(json.contains("Session 125"))
    }
}

@MainActor
final class PushNotificationColdLaunchTests: XCTestCase {
    func testBootstrapFromLaunchQueuesSessionId() {
        let service = PushNotificationService.shared
        _ = service.consumePendingSessionId()

        let userInfo: [AnyHashable: Any] = [
            "session_id": "125",
            "type": "chat_reply_ready",
            "message_id": "698",
        ]
        service.bootstrapFromLaunch(remoteNotification: userInfo)

        XCTAssertEqual(service.consumePendingSessionId(), "125")
    }

    func testAttachNavigationHandlerDrainsPendingSession() {
        let service = PushNotificationService.shared
        _ = service.consumePendingSessionId()

        service.bootstrapFromLaunch(remoteNotification: ["session_id": "56"])

        var opened: String?
        service.attachNavigationHandler { opened = $0 }

        XCTAssertEqual(opened, "56")
        XCTAssertNil(service.consumePendingSessionId())
    }

    func testAttachNavigationHandlerWiresFutureTaps() {
        let service = PushNotificationService.shared
        _ = service.consumePendingSessionId()

        var opened: String?
        service.attachNavigationHandler { opened = $0 }
        XCTAssertNil(opened)

        service.onOpenSession?("29")
        XCTAssertEqual(opened, "29")
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
