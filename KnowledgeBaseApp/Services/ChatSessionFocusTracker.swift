import Foundation

/// Tracks which chat session is visible (for suppressing push banners on the same thread).
@MainActor
final class ChatSessionFocusTracker {
    static let shared = ChatSessionFocusTracker()

    private(set) var focusedSessionId: String?

    private init() {}

    func setFocusedSessionId(_ sessionId: String?) {
        focusedSessionId = sessionId
    }
}
