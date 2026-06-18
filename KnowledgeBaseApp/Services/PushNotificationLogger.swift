import Foundation
import UserNotifications

/// Structured push interaction logs (tag: `Push` in Log settings).
enum PushNotificationLogger {
    private static let logger = makeLogger(tag: .push)

    static func receivedInForeground(
        userInfo: [AnyHashable: Any],
        focusedSessionId: String?,
        presentation: String
    ) {
        logger.debugInfo(
            "[push] foreground received focused=\(focusedSessionId ?? "nil") presentation=\(presentation) payload=\(PushPayloadFormatter.json(userInfo))"
        )
    }

    static func receivedInBackground(userInfo: [AnyHashable: Any]) {
        logger.debugInfo(
            "[push] background received payload=\(PushPayloadFormatter.json(userInfo))"
        )
    }

    static func openedFromColdLaunch(userInfo: [AnyHashable: Any], sessionId: String) {
        logger.debugInfo(
            "[push] cold launch from notification sessionId=\(sessionId) payload=\(PushPayloadFormatter.json(userInfo))"
        )
    }

    static func userTapped(
        response: UNNotificationResponse,
        sessionId: String?
    ) {
        let userInfo = response.notification.request.content.userInfo
        logger.debugInfo(
            "[push] user tapped action=\(response.actionIdentifier) sessionId=\(sessionId ?? "nil") deliveredAt=\(response.notification.date) payload=\(PushPayloadFormatter.json(userInfo))"
        )
    }

    static func navigatingToSession(sessionId: String, source: String) {
        logger.debugInfo("[push] navigate sessionId=\(sessionId) source=\(source)")
    }

    static func consumedPendingSession(sessionId: String) {
        logger.debugInfo("[push] consumed pending sessionId=\(sessionId) source=cold_start_delegate")
    }
}
