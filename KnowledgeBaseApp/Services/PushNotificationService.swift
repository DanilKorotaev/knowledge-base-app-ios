import Foundation
import UIKit
import UserNotifications

/// Remote push registration, server sync, and notification delegate (chat reply ready).
@MainActor
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private let logger = makeLogger(tag: .push)

    private(set) var deviceTokenHex: String?
    private(set) var pendingSessionId: String?

    var onOpenSession: ((String) -> Void)?

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Call synchronously from `application(_:didFinishLaunchingWithOptions:)` on the main thread
    /// so the notification delegate is installed before iOS delivers a cold-start tap.
    func bootstrapFromLaunch(remoteNotification: [AnyHashable: Any]?) {
        configure()
        guard let remoteNotification else { return }
        handleLaunchFromRemoteNotification(remoteNotification)
    }

    /// Wire SwiftUI navigation and drain any session id queued during launch.
    func attachNavigationHandler(_ handler: @escaping (String) -> Void) {
        onOpenSession = handler
        if let pending = consumePendingSessionId() {
            handler(pending)
        }
    }

    func requestAuthorizationAndRegister() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return }
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                self.logger.debugInfo("Push authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        deviceTokenHex = hex
        logger.debugInfo("APNs device token registered (…\(hex.suffix(8)))")
        Task {
            await syncDeviceTokenToServer(hex)
        }
    }

    func didFailToRegister(error: Error) {
        logger.debugInfo("APNs registration failed: \(error.localizedDescription)")
    }

    func unregisterFromServer() async {
        guard let hex = deviceTokenHex else { return }
        guard let client = URLSessionKnowledgeBaseAPIClient() else { return }
        do {
            try await client.unregisterDevice(token: hex)
            logger.debugInfo("Device token unregistered from server")
        } catch {
            logger.debugInfo("Device unregister failed: \(error.localizedDescription)")
        }
    }

    private func syncDeviceTokenToServer(_ hex: String) async {
        guard let client = URLSessionKnowledgeBaseAPIClient() else { return }
        let environment = Self.currentApnsEnvironment
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        do {
            try await client.registerDevice(
                token: hex,
                apnsEnvironment: environment,
                appVersion: version
            )
            logger.debugInfo("Device token synced (\(environment))")
        } catch {
            logger.debugInfo("Device register failed: \(error.localizedDescription)")
        }
    }

    static var currentApnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// App launched from a remote notification (cold start).
    func handleLaunchFromRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let sessionId = Self.sessionId(from: userInfo) else {
            logger.debugInfo(
                "[push] cold launch notification without session_id payload=\(PushPayloadFormatter.json(userInfo))"
            )
            return
        }
        pendingSessionId = sessionId
        PushNotificationLogger.openedFromColdLaunch(userInfo: userInfo, sessionId: sessionId)
    }

    /// Background / silent remote notification delivery.
    func handleBackgroundRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        PushNotificationLogger.receivedInBackground(userInfo: userInfo)
    }

    func consumePendingSessionId() -> String? {
        let id = pendingSessionId
        pendingSessionId = nil
        if let id {
            PushNotificationLogger.consumedPendingSession(sessionId: id)
        }
        return id
    }

    private func openSession(_ sessionId: String, source: String) {
        PushNotificationLogger.navigatingToSession(sessionId: sessionId, source: source)
        pendingSessionId = sessionId
        onOpenSession?(sessionId)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        guard let sessionId = Self.sessionId(from: userInfo) else {
            PushNotificationLogger.receivedInForeground(
                userInfo: userInfo,
                focusedSessionId: nil,
                presentation: "banner,sound"
            )
            return [.banner, .sound]
        }
        let focused = await ChatSessionFocusTracker.shared.focusedSessionId
        if focused == sessionId {
            PushNotificationLogger.receivedInForeground(
                userInfo: userInfo,
                focusedSessionId: focused,
                presentation: "suppressed"
            )
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .kbSessionThreadDidChange,
                    object: nil,
                    userInfo: [KBNotificationUserInfoKey.sessionId: sessionId]
                )
            }
            return []
        }
        PushNotificationLogger.receivedInForeground(
            userInfo: userInfo,
            focusedSessionId: focused,
            presentation: "banner,sound"
        )
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let sessionId = Self.sessionId(from: userInfo) else {
            PushNotificationLogger.userTapped(response: response, sessionId: nil)
            return
        }
        PushNotificationLogger.userTapped(response: response, sessionId: sessionId)
        await MainActor.run {
            openSession(sessionId, source: "notification_tap")
        }
    }

    nonisolated static func sessionId(from userInfo: [AnyHashable: Any]) -> String? {
        if let sid = userInfo["session_id"] as? String, !sid.isEmpty {
            return sid
        }
        if let sid = userInfo["session_id"] as? Int {
            return String(sid)
        }
        return nil
    }

    nonisolated static func parseSessionId(from url: URL) -> String? {
        guard url.scheme == "knowledgebase", url.host == "session" else { return nil }
        let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return id.isEmpty ? nil : id
    }
}
