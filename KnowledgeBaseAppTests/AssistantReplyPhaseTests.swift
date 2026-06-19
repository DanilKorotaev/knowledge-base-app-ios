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
            XCTAssertNil(parsed?.activityLabel)
        }
    }

    func testStreamConsumer_phasesEndInFinalizing() async throws {
        let stream = AsyncThrowingStream<AssistantStreamEvent, Error> { continuation in
            continuation.yield(.delta("a"))
            continuation.yield(.delta("b"))
            continuation.finish()
        }
        var updates: [AssistantReplyStreamUpdate] = []
        try await AssistantReplyStreamConsumer.consume(stream) { update in
            updates.append(update)
        }
        XCTAssertEqual(updates.map(\.phase), [
            .waiting,
            .streaming(text: "a"),
            .streaming(text: "ab"),
            .finalizing(text: "ab"),
        ])
        XCTAssertNil(updates[0].activityLabel)
        XCTAssertNil(updates.last?.activityLabel)
    }

    func testStreamConsumer_activityClearsOnFirstDelta() async throws {
        let stream = AsyncThrowingStream<AssistantStreamEvent, Error> { continuation in
            continuation.yield(.activity(label: "Запускаю тесты…"))
            continuation.yield(.delta("Hi"))
            continuation.finish()
        }
        var updates: [AssistantReplyStreamUpdate] = []
        try await AssistantReplyStreamConsumer.consume(stream) { update in
            updates.append(update)
        }
        XCTAssertEqual(updates[1].activityLabel, "Запускаю тесты…")
        XCTAssertNil(updates[2].activityLabel)
        XCTAssertEqual(updates[2].phase, .streaming(text: "Hi"))
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

    func testNotificationRoundTrip_withActivityLabel() {
        AssistantReplyPhaseNotification.post(
            sessionId: "s3",
            phase: .waiting,
            activityLabel: "Читаю README.md…"
        )
        let notification = Notification(
            name: AssistantReplyPhaseNotification.name,
            object: nil,
            userInfo: [
                KBNotificationUserInfoKey.sessionId: "s3",
                KBNotificationUserInfoKey.assistantReplyPhaseKind: "waiting",
                KBNotificationUserInfoKey.assistantReplyActivityLabel: "Читаю README.md…",
            ]
        )
        let parsed = AssistantReplyPhaseNotification.parse(notification)
        XCTAssertEqual(parsed?.activityLabel, "Читаю README.md…")
        XCTAssertEqual(parsed?.phase, .waiting)
    }

    func testShowsPlaceholderAndDisplayText() {
        XCTAssertFalse(AssistantReplyPhase.idle.showsPlaceholder)
        XCTAssertTrue(AssistantReplyPhase.waiting.showsPlaceholder)
        XCTAssertEqual(AssistantReplyPhase.streaming(text: "x").displayText, "x")
        XCTAssertEqual(AssistantReplyPhase.finalizing(text: "done").displayText, "done")
        XCTAssertNil(AssistantReplyPhase(notificationKind: "unknown", text: nil))
    }
}
