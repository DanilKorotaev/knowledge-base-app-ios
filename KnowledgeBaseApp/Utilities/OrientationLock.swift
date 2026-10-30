import UIKit

/// App-wide orientation mask; default portrait. Table fullscreen enables landscape.
@MainActor
enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = .portrait

    static func setLandscapeAllowed(_ allowed: Bool) {
        mask = allowed ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
        applyToActiveScene()
    }

    private static func applyToActiveScene() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return
        }
        let orientations: UIInterfaceOrientationMask = mask
        // Completion error is non-optional on current SDK; ignore failures (user can rotate manually).
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
