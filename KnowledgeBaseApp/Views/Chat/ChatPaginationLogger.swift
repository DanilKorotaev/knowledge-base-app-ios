import SwiftUI

/// Debug logging for chat message pagination and scroll triggers (tag: `Chat` in Log settings).
enum ChatPaginationLogger {
    private static let logger = makeLogger(tag: .chat)
    private static var lastGeometryLogTime: CFAbsoluteTime = 0
    private static let geometryLogInterval: CFAbsoluteTime = 0.35

    static func sessionTaskStarted(sessionId: String) {
        logger.debugInfo("[pagination] session task started id=\(sessionId)")
    }

    static func scrollStateReset() {
        logger.debugInfo("[pagination] scroll state reset")
    }

    static func scrollArmed(afterSeconds: Double) {
        logger.debugInfo("[pagination] scroll armed (older loads allowed after \(afterSeconds)s)")
    }

    static func scrollSample(_ sample: ScrollPaginationSample, force: Bool = false) {
        let now = CFAbsoluteTimeGetCurrent()
        guard force || now - lastGeometryLogTime >= geometryLogInterval else { return }
        lastGeometryLogTime = now
        logger.debugInfo("[pagination] geometry \(sample.snapshot) edge=\(sample.isNearOldestEdge)")
    }

    static func oldestEdgeTransition(wasNear: Bool, isNear: Bool, geometrySnapshot: String) {
        logger.debugInfo(
            "[pagination] oldest-edge transition was=\(wasNear) now=\(isNear) | \(geometrySnapshot)"
        )
    }

    static func oldestMessageAppeared(messageId: String, firstMessageId: String?) {
        logger.debugInfo(
            "[pagination] oldest bubble onAppear id=\(messageId) firstLoaded=\(firstMessageId ?? "nil") matchesFirst=\(messageId == firstMessageId)"
        )
    }

    static func scrollIntent(_ intent: ChatScrollIntent) {
        logger.debugInfo("[pagination] scroll intent \(String(describing: intent))")
    }

    static func paginationSuppressed(untilSeconds: TimeInterval) {
        logger.debugInfo("[pagination] suppress auto-load for \(untilSeconds)s after prepend")
    }

    static func requestBlocked(_ reason: String, context: String) {
        logger.warning("[pagination] load older BLOCKED (\(context)): \(reason)")
    }

    static func requestStarted(source: String, anchorId: String?) {
        logger.debugInfo("[pagination] load older START source=\(source) before=\(anchorId ?? "nil")")
    }

    static func initialLoadStarted(sessionId: String) {
        logger.debugInfo("[pagination] initial load START session=\(sessionId)")
    }

    static func pageApplied(
        kind: String,
        messageIds: [String],
        total: Int,
        hasMoreOlder: Bool,
        windowCount: Int
    ) {
        let ids = messageIds.joined(separator: ",")
        logger.debugInfo(
            "[pagination] \(kind) applied ids=[\(ids)] total=\(total) hasMoreOlder=\(hasMoreOlder) window=\(windowCount)"
        )
    }

    static func loadFailed(_ kind: String, error: String) {
        logger.debugError("[pagination] \(kind) FAILED: \(error)")
    }
}
