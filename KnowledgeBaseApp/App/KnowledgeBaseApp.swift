import SwiftUI

@main
struct KnowledgeBaseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deepLinkVoiceRecording = false

    init() {
        UserDefaultsService.shared = UserDefaultsService(settings: UserDefaultsInspectorSettings.shared)
        UserDefaultsInspectorLogger.shared.start()
        _ = LogFilesProvider.shared
        _ = LogSession.shared
    }

    var body: some Scene {
        WindowGroup {
            MainView(deepLinkVoiceRecording: $deepLinkVoiceRecording)
                .onOpenURL { url in
                    guard url.scheme == "knowledgebase" else { return }
                    if url.host == "record" {
                        deepLinkVoiceRecording = true
                    }
                }
        }
    }
}
