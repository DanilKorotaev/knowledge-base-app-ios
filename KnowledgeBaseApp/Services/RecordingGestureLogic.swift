import CoreGraphics

/// Pure gesture thresholds (Telegram-style: left = cancel, up = lock). Testable without UIKit.
enum RecordingGestureLogic: Sendable {
    static let cancelDragPoints: CGFloat = 64
    static let lockDragPoints: CGFloat = 56

    /// Whether a left swipe past the threshold should cancel (only while not locked and not already cancelling).
    static func shouldTriggerCancel(translation: CGSize, isLocked: Bool, alreadyCancelled: Bool) -> Bool {
        guard !isLocked, !alreadyCancelled else { return false }
        return translation.width < -cancelDragPoints
    }

    /// Whether an upward swipe past the threshold should lock (only while not locked / not cancelled).
    static func shouldTriggerLock(translation: CGSize, isLocked: Bool, alreadyCancelled: Bool) -> Bool {
        guard !isLocked, !alreadyCancelled else { return false }
        return translation.height < -lockDragPoints
    }
}
