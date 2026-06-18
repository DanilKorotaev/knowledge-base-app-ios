import SwiftUI

@main
struct KnowledgeBaseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deepLinkVoiceRecording = false
    @State private var deepLinkSessionId: String?

    init() {
        UserDefaultsService.shared = UserDefaultsService(settings: UserDefaultsInspectorSettings.shared)
        UserDefaultsInspectorLogger.shared.start()
        _ = LogFilesProvider.shared
        _ = LogSession.shared
        #if canImport(WatchConnectivity)
        WatchVoiceSessionContextSync.shared.activateIfNeeded()
        WatchRelayLog.localSink = { line in
            WatchRelayLogger.ingestWatchLine(line)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView(
                deepLinkVoiceRecording: $deepLinkVoiceRecording,
                deepLinkSessionId: $deepLinkSessionId
            )
            .onOpenURL { url in
                guard url.scheme == "knowledgebase" else { return }
                if url.host == "record" {
                    deepLinkVoiceRecording = true
                } else if let sessionId = PushNotificationService.parseSessionId(from: url) {
                    deepLinkSessionId = sessionId
                }
            }
            .onAppear {
                PushNotificationService.shared.attachNavigationHandler { sessionId in
                    deepLinkSessionId = sessionId
                }
            }
        }
    }
}
