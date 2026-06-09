import SwiftUI

@main
struct KnowledgeBaseWatchApp: App {
    @State private var viewModel = WatchVoiceViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchMainView(viewModel: viewModel)
            }
            .onOpenURL { url in
                guard url.scheme == "knowledgebase", url.host == "record" else { return }
                NotificationCenter.default.post(name: .watchStartRecordingImmediately, object: nil)
            }
        }
    }
}
