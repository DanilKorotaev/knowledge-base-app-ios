import UIKit

/// Prevents auto-lock while the user is actively recording voice (Low Power Mode friendly).
protocol ScreenIdleTimerLocking: AnyObject {
    func setIdleTimerDisabled(_ disabled: Bool)
}

/// Reference-counted wrapper so nested acquire/release stays balanced.
final class UIApplicationScreenIdleTimerLock: ScreenIdleTimerLocking {
    static let shared = UIApplicationScreenIdleTimerLock()

    private var depth = 0

    func setIdleTimerDisabled(_ disabled: Bool) {
        if disabled {
            depth += 1
            if depth == 1 {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            return
        }
        depth = max(0, depth - 1)
        if depth == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

final class NoOpScreenIdleTimerLock: ScreenIdleTimerLocking {
    func setIdleTimerDisabled(_ disabled: Bool) {}
}
