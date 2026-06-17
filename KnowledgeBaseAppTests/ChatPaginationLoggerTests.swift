import XCTest
@testable import KnowledgeBaseApp

final class ChatPaginationLoggerTests: XCTestCase {
    private var previousDebug: Bool!
    private var previousChatTag: Bool!

    override func setUp() {
        super.setUp()
        previousDebug = KBLoggerSettings.shared.isDebugLogger
        previousChatTag = KBLoggerTagsProvider.shared.isEnabled(tag: .chat)
        KBLoggerSettings.shared.isDebugLogger = true
        KBLoggerTagsProvider.shared.set(isEnabled: true, for: .chat)
    }

    override func tearDown() {
        KBLoggerSettings.shared.isDebugLogger = previousDebug
        KBLoggerTagsProvider.shared.set(isEnabled: previousChatTag, for: .chat)
        super.tearDown()
    }

    func testLogsPaginationLifecycle() {
        ChatPaginationLogger.sessionTaskStarted(sessionId: "session-1")
        ChatPaginationLogger.scrollStateReset()
        ChatPaginationLogger.scrollArmed(afterSeconds: 1.5)
        ChatPaginationLogger.oldestEdgeTransition(
            wasNear: false,
            isNear: true,
            geometrySnapshot: "offsetY=0"
        )
        ChatPaginationLogger.oldestMessageAppeared(messageId: "m1", firstMessageId: "m1")
        ChatPaginationLogger.scrollIntent(.scrollToBottom)
        ChatPaginationLogger.scrollIntent(.preserve(messageId: "m1"))
        ChatPaginationLogger.paginationSuppressed(untilSeconds: 2)
        ChatPaginationLogger.requestBlocked("busy", context: "test")
        ChatPaginationLogger.requestStarted(source: "edge", anchorId: "m0")
        ChatPaginationLogger.initialLoadStarted(sessionId: "session-1")
        ChatPaginationLogger.pageApplied(
            kind: "older",
            messageIds: ["m0", "m1"],
            total: 2,
            hasMoreOlder: false,
            windowCount: 2
        )
        ChatPaginationLogger.loadFailed("older", error: "network")
        ChatPaginationLogger.streamingDelta(index: 1, deltaChars: 3, totalChars: 10)
        ChatPaginationLogger.streamingFinished(chunks: 4, totalChars: 10)
    }
}
