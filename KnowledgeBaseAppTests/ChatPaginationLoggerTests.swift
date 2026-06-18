import XCTest
@testable import KnowledgeBaseApp

final class ChatPaginationLoggerTests: XCTestCase {
    func testLoggingMethodsDoNotTrap() {
        ChatPaginationLogger.sessionTaskStarted(sessionId: "42")
        ChatPaginationLogger.scrollStateReset()
        ChatPaginationLogger.scrollArmed(afterSeconds: 0.4)
        ChatPaginationLogger.scrollSample(
            ScrollPaginationSample(
                isNearOldestEdge: true,
                offsetBucket: -3,
                snapshot: "offsetY=-120.0 near=YES"
            ),
            force: true
        )
        ChatPaginationLogger.oldestEdgeTransition(
            wasNear: false,
            isNear: true,
            geometrySnapshot: "offsetY=-120.0"
        )
        ChatPaginationLogger.oldestMessageAppeared(messageId: "m1", firstMessageId: "m1")
        ChatPaginationLogger.scrollIntent(.scrollToBottom)
        ChatPaginationLogger.paginationSuppressed(untilSeconds: 0.5)
        ChatPaginationLogger.requestBlocked("not ready", context: "test")
        ChatPaginationLogger.requestStarted(source: "scroll-geometry", anchorId: "m0")
        ChatPaginationLogger.initialLoadStarted(sessionId: "42")
        ChatPaginationLogger.pageApplied(
            kind: "older",
            messageIds: ["a", "b"],
            total: 94,
            hasMoreOlder: true,
            windowCount: 10
        )
        ChatPaginationLogger.loadFailed("older", error: "network")
        ChatPaginationLogger.streamingDelta(index: 1, deltaChars: 12, totalChars: 12)
        ChatPaginationLogger.streamingFinished(chunks: 3, totalChars: 48)
    }

    func testScrollSampleThrottlesWithoutForce() {
        let sample = ScrollPaginationSample(
            isNearOldestEdge: false,
            offsetBucket: 10,
            snapshot: "offsetY=400.0 near=no"
        )
        ChatPaginationLogger.scrollSample(sample, force: true)
        ChatPaginationLogger.scrollSample(sample, force: false)
        ChatPaginationLogger.scrollSample(sample, force: false)
    }

    func testScrollPaginationSampleEquatableIgnoresSnapshot() {
        let a = ScrollPaginationSample(isNearOldestEdge: true, offsetBucket: 1, snapshot: "a")
        let b = ScrollPaginationSample(isNearOldestEdge: true, offsetBucket: 1, snapshot: "b")
        XCTAssertEqual(a, b)
    }
}
