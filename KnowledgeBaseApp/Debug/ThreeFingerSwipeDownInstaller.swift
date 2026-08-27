import UIKit

/// Installs a 3-finger swipe-down recognizer on the key window (does not steal one-finger scrolls).
@MainActor
final class ThreeFingerSwipeDownInstaller {
    static let shared = ThreeFingerSwipeDownInstaller()

    private weak var installedWindow: UIWindow?
    private var recognizer: UIPanGestureRecognizer?
    private var onSwipeDown: (() -> Void)?
    private var didFire = false
    private var isEnabled = false

    private init() {}

    func setEnabled(_ enabled: Bool, onSwipeDown: @escaping () -> Void) {
        self.onSwipeDown = onSwipeDown
        isEnabled = enabled
        if enabled {
            ensureInstalled()
            recognizer?.isEnabled = true
        } else {
            recognizer?.isEnabled = false
        }
    }

    private func ensureInstalled() {
        guard let window = Self.keyWindow() else { return }
        if installedWindow === window, recognizer != nil { return }

        if let old = recognizer {
            installedWindow?.removeGestureRecognizer(old)
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 3
        pan.maximumNumberOfTouches = 3
        pan.cancelsTouchesInView = false
        pan.delegate = GestureDelegate.shared
        window.addGestureRecognizer(pan)
        recognizer = pan
        installedWindow = window
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isEnabled else { return }
        switch gesture.state {
        case .began:
            didFire = false
        case .changed:
            guard !didFire else { return }
            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            if translation.y > 90, abs(translation.x) < abs(translation.y) * 0.85, velocity.y > 250 {
                didFire = true
                onSwipeDown?()
            }
        case .ended, .cancelled, .failed:
            didFire = false
        default:
            break
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

private final class GestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = GestureDelegate()

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
