import XCTest
@testable import KnowledgeBaseApp

final class AssistantReplyPhaseTests: XCTestCase {
    func testShowsPendingSpinner_onlyWhileWaitingOrEmptyStream() {
        XCTAssertTrue(AssistantReplyPhase.waiting.showsPendingSpinner)
        XCTAssertTrue(AssistantReplyPhase.streaming(text: "").showsPendingSpinner)
        XCTAssertFalse(AssistantReplyPhase.streaming(text: "hi").showsPendingSpinner)
        XCTAssertFalse(AssistantReplyPhase.finalizing(text: "hi").showsPendingSpinner)
        XCTAssertFalse(AssistantReplyPhase.idle.showsPendingSpinner)
    }

    func testShowsTypingIndicator_whileWaitingOrEmptyStream() {
        XCTAssertTrue(AssistantReplyPhase.waiting.showsTypingIndicator)
        XCTAssertTrue(AssistantReplyPhase.streaming(text: "").showsTypingIndicator)
        XCTAssertFalse(AssistantReplyPhase.streaming(text: "chunk").showsTypingIndicator)
        XCTAssertFalse(AssistantReplyPhase.finalizing(text: "done").showsTypingIndicator)
    }

    func testNotificationRoundTrip() {
        let phases: [AssistantReplyPhase] = [
            .idle,
            .waiting,
            .streaming(text: "partial"),
            .finalizing(text: "done"),
        ]
        for phase in phases {
            var userInfo: [String: Any] = [
                KBNotificationUserInfoKey.sessionId: "s1",
                KBNotificationUserInfoKey.assistantReplyPhaseKind: phase.notificationKind,
            ]
            if !phase.displayText.isEmpty {
                userInfo[KBNotificationUserInfoKey.assistantReplyPhaseText] = phase.displayText
            }
            let notification = Notification(name: AssistantReplyPhaseNotification.name, object: nil, userInfo: userInfo)
            let parsed = AssistantReplyPhaseNotification.parse(notification)
            XCTAssertEqual(parsed?.sessionId, "s1")
            XCTAssertEqual(parsed?.phase, phase)
        }
    }

    func testStreamConsumer_phasesEndInFinalizing() async throws {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.finish()
        }
        var phases: [AssistantReplyPhase] = []
        try await AssistantReplyStreamConsumer.consume(stream) { phase in
            phases.append(phase)
        }
        XCTAssertEqual(phases, [
            .waiting,
            .streaming(text: "a"),
            .streaming(text: "ab"),
            .finalizing(text: "ab"),
        ])
    }

    func testNotificationPostAndParse_idleOmitsTextKey() {
        AssistantReplyPhaseNotification.post(sessionId: "s2", phase: .idle)
        let notification = Notification(
            name: AssistantReplyPhaseNotification.name,
            object: nil,
            userInfo: [
                KBNotificationUserInfoKey.sessionId: "s2",
                KBNotificationUserInfoKey.assistantReplyPhaseKind: "idle",
            ]
        )
        XCTAssertEqual(AssistantReplyPhaseNotification.parse(notification)?.phase, .idle)
    }

    func testShowsPlaceholderAndDisplayText() {
        XCTAssertFalse(AssistantReplyPhase.idle.showsPlaceholder)
        XCTAssertTrue(AssistantReplyPhase.waiting.showsPlaceholder)
        XCTAssertEqual(AssistantReplyPhase.streaming(text: "x").displayText, "x")
        XCTAssertEqual(AssistantReplyPhase.finalizing(text: "done").displayText, "done")
        XCTAssertNil(AssistantReplyPhase(notificationKind: "unknown", text: nil))
    }
}
