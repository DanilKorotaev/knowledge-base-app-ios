import SwiftUI
import UIKit

/// Installs a window-level shake monitor so shake works even when a text field is focused.
struct ShakeDetectorView: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorInstallerController {
        let controller = ShakeDetectorInstallerController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorInstallerController, context: Context) {
        uiViewController.onShake = onShake
        uiViewController.installIfNeeded()
    }
}

final class ShakeDetectorInstallerController: UIViewController {
    var onShake: (() -> Void)? {
        didSet { monitor?.onShake = onShake }
    }

    private var monitor: ShakeMonitorViewController?
    private var keyboardObservers: [NSObjectProtocol] = []

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    func installIfNeeded() {
        guard monitor == nil else {
            monitor?.claimFirstResponder()
            return
        }
        guard let host = keyWindow()?.rootViewController else { return }

        let monitor = ShakeMonitorViewController()
        monitor.onShake = onShake
        host.addChild(monitor)
        monitor.view.frame = .zero
        monitor.view.isUserInteractionEnabled = false
        monitor.view.autoresizingMask = []
        host.view.addSubview(monitor.view)
        monitor.didMove(toParent: host)
        self.monitor = monitor
        monitor.claimFirstResponder()

        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardDidHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.monitor?.claimFirstResponder()
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.monitor?.claimFirstResponder()
            },
        ]
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

final class ShakeMonitorViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    func claimFirstResponder() {
        guard !isFirstResponder else { return }
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}
