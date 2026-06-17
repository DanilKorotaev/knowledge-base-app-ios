import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        #if canImport(WatchConnectivity)
        WatchVoiceSessionContextSync.shared.activateIfNeeded()
        WatchVoiceSessionContextSync.shared.publish(DefaultVoiceSessionStore.shared.load())
        #endif
    }
}
