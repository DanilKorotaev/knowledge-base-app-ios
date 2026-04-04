import Foundation

extension Notification.Name {
    /// Posted when a session’s message thread changes outside the active `ChatViewModel` (e.g. voice send from the mic bar).
    static let kbSessionThreadDidChange = Notification.Name("kbSessionThreadDidChange")
}

enum KBNotificationUserInfoKey {
    static let sessionId = "sessionId"
}
