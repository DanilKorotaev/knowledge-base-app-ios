import UIKit
import UserNotifications

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

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(WatchConnectivity)
        WatchVoiceSessionContextSync.shared.activateIfNeeded()
        #endif
        let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any]
        MainActor.assumeIsolated {
            PushNotificationService.shared.bootstrapFromLaunch(remoteNotification: remote)
        }
        Task { @MainActor in
            PushNotificationService.shared.requestAuthorizationAndRegister()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleBackgroundRemoteNotification(userInfo)
            completionHandler(.noData)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegister(error: error)
        }
    }
}
