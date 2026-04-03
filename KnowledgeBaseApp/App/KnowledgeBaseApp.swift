import SwiftUI

@main
struct KnowledgeBaseApp: App {
    @State private var deepLinkVoiceRecording = false

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
