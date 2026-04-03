import CoreGraphics
import XCTest
@testable import KnowledgeBaseApp

final class RecordingGestureLogicTests: XCTestCase {
    func testCancelWhenSwipeLeftPastThreshold() {
        let t = CGSize(width: -70, height: 0)
        XCTAssertTrue(
            RecordingGestureLogic.shouldTriggerCancel(translation: t, isLocked: false, alreadyCancelled: false)
        )
        XCTAssertFalse(
            RecordingGestureLogic.shouldTriggerCancel(translation: t, isLocked: true, alreadyCancelled: false)
        )
        XCTAssertFalse(
            RecordingGestureLogic.shouldTriggerCancel(translation: t, isLocked: false, alreadyCancelled: true)
        )
    }

    func testLockWhenSwipeUpPastThreshold() {
        let t = CGSize(width: 0, height: -60)
        XCTAssertTrue(
            RecordingGestureLogic.shouldTriggerLock(translation: t, isLocked: false, alreadyCancelled: false)
        )
        XCTAssertFalse(
            RecordingGestureLogic.shouldTriggerLock(translation: t, isLocked: true, alreadyCancelled: false)
        )
    }

    func testNoCancelWhenBarelyMoved() {
        let t = CGSize(width: -10, height: -10)
        XCTAssertFalse(
            RecordingGestureLogic.shouldTriggerCancel(translation: t, isLocked: false, alreadyCancelled: false)
        )
    }
}
