import Foundation

/// Release-visible timing for chat open / load (tag: `Chat` in Log settings).
enum ChatOpenLogger {
    private static let logger = makeLogger(tag: .chat)

    static func sessionRowTapped(sessionId: String) {
        logger.releaseInfo("[chat-open] session row tapped id=\(sessionId)")
    }

    static func viewAppeared(sessionId: String) {
        logger.releaseInfo("[chat-open] view appeared id=\(sessionId)")
    }

    static func cacheBootstrapFinished(sessionId: String, messageCount: Int, milliseconds: Int) {
        logger.releaseInfo(
            "[chat-open] cache ready id=\(sessionId) messages=\(messageCount) ms=\(milliseconds)"
        )
    }

    static func networkLoadFinished(sessionId: String, messageCount: Int, milliseconds: Int) {
        logger.releaseInfo(
            "[chat-open] network ready id=\(sessionId) messages=\(messageCount) ms=\(milliseconds)"
        )
    }

    static func initialLayoutReady(sessionId: String, milliseconds: Int) {
        logger.releaseInfo("[chat-open] scroll armed id=\(sessionId) ms=\(milliseconds)")
    }
}
