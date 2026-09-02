import SwiftUI

@main
struct KnowledgeBaseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deepLinkVoiceRecording = false
    @State private var deepLinkSessionId: String?
    @State private var debugQuickActions = DebugQuickActionsController.shared
    @Bindable private var languageStore = AppLanguageStore.shared

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
        NetworkPathMonitor.shared.start()
        // Ensure App Group draft root exists and legacy Application Support drafts are copied once.
        _ = ComposerDraftStore.shared
        // Promote Settings token into the shared Keychain access group for Share Extension.
        _ = KeychainTokenStore.token()
    }

    var body: some Scene {
        WindowGroup {
            @Bindable var debugQuickActions = debugQuickActions
            MainView(
                deepLinkVoiceRecording: $deepLinkVoiceRecording,
                deepLinkSessionId: $deepLinkSessionId
            )
            .environment(\.locale, languageStore.resolvedLocale)
            .environment(languageStore)
            .background {
                ShakeDetectorView {
                    debugQuickActions.handleDeviceShake()
                }
                .frame(width: 0, height: 0)
            }
            .alert(
                L10n.string("debug.send_logs_title"),
                isPresented: $debugQuickActions.showSendLogsConfirm
            ) {
                Button(L10n.string("debug.send")) {
                    Task { await debugQuickActions.confirmSendLogs() }
                }
                Button(L10n.string("common.cancel"), role: .cancel) {
                    debugQuickActions.cancelSendLogs()
                }
            } message: {
                Text(L10n.string("debug.send_logs_message"))
            }
            .alert(
                L10n.string("debug.title"),
                isPresented: Binding(
                    get: { debugQuickActions.statusMessage != nil },
                    set: { if !$0 { debugQuickActions.clearStatusMessage() } }
                )
            ) {
                Button(L10n.string("common.ok"), role: .cancel) {
                    debugQuickActions.clearStatusMessage()
                }
            } message: {
                Text(debugQuickActions.statusMessage ?? "")
            }
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
