import UIKit

/// Prevents auto-lock while the user is actively recording voice (Low Power Mode friendly).
protocol ScreenIdleTimerLocking: AnyObject {
    func setIdleTimerDisabled(_ disabled: Bool)
}

/// Single-owner lock — ViewModel is the only caller; always sets UIKit state directly.
final class UIApplicationScreenIdleTimerLock: ScreenIdleTimerLocking {
    static let shared = UIApplicationScreenIdleTimerLock()

    func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}

final class NoOpScreenIdleTimerLock: ScreenIdleTimerLocking {
    private(set) var isDisabled = false

    func setIdleTimerDisabled(_ disabled: Bool) {
        isDisabled = disabled
    }
}
