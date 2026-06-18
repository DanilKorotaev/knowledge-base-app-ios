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

    func testParseSessionIdFromUserInfoInt() {
        let info: [AnyHashable: Any] = ["session_id": 125, "type": "chat_reply_ready"]
        XCTAssertEqual(PushNotificationService.sessionId(from: info), "125")
    }

    func testParseSessionIdIgnoresEmptyString() {
        XCTAssertNil(PushNotificationService.sessionId(from: ["session_id": ""]))
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

    func testPayloadFormatterHandlesDatesBinaryAndURLs() {
        let userInfo: [AnyHashable: Any] = [
            "when": Date(timeIntervalSince1970: 0),
            "blob": Data([0xAB, 0xCD]),
            "link": URL(string: "https://example.com")!,
            "nums": [1, 2, 3],
        ]
        let json = PushPayloadFormatter.json(userInfo)
        XCTAssertTrue(json.contains("1970"))
        XCTAssertTrue(json.contains("q80=")) // base64 of 0xABCD
        XCTAssertTrue(json.contains("nums"))
    }

    func testPayloadFormatterFallsBackForNonJSONValues() {
        struct Opaque: CustomStringConvertible {
            var description: String { "opaque-value" }
        }
        let json = PushPayloadFormatter.json(["key": Opaque()])
        XCTAssertTrue(json.contains("opaque-value"))
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

    func testBootstrapFromLaunchWithoutRemoteLeavesPendingEmpty() {
        let service = PushNotificationService.shared
        _ = service.consumePendingSessionId()

        service.bootstrapFromLaunch(remoteNotification: nil)

        XCTAssertNil(service.consumePendingSessionId())
    }

    func testBootstrapFromLaunchWithoutSessionIdDoesNotQueue() {
        let service = PushNotificationService.shared
        _ = service.consumePendingSessionId()

        service.bootstrapFromLaunch(remoteNotification: ["type": "chat_reply_ready", "message_id": "1"])

        XCTAssertNil(service.consumePendingSessionId())
    }
}

@MainActor
final class PushNotificationLoggerTests: XCTestCase {
    func testLoggerMethodsAcceptRealisticPayload() {
        let userInfo: [AnyHashable: Any] = [
            "type": "chat_reply_ready",
            "session_id": "125",
            "message_id": "698",
            "aps": [
                "alert": ["title": "Session 125", "body": "Preview"],
                "sound": "default",
                "thread-id": "125",
            ] as [String: Any],
        ]
        PushNotificationLogger.receivedInForeground(
            userInfo: userInfo,
            focusedSessionId: "29",
            presentation: "banner,sound"
        )
        PushNotificationLogger.receivedInBackground(userInfo: userInfo)
        PushNotificationLogger.openedFromColdLaunch(userInfo: userInfo, sessionId: "125")
        PushNotificationLogger.navigatingToSession(sessionId: "125", source: "test")
        PushNotificationLogger.consumedPendingSession(sessionId: "125")
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
