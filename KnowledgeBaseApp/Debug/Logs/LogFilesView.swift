import SwiftUI

final class LogFilesViewModel: ObservableObject {
    @Published var mainAppItems: [LogFileEntry] = []
    @Published var shareItems: [LogFileEntry] = []

    func reload() {
        let entries = LogFilesProvider.shared.allLogFileEntries
        mainAppItems = entries.filter { $0.source == .mainApp }
        shareItems = entries.filter { $0.source == .shareExtension }
    }
}

struct LogFilesView: View {
    @StateObject private var viewModel = LogFilesViewModel()

    var body: some View {
        List {
            Section {
                if viewModel.mainAppItems.isEmpty {
                    Text(L10n.string("logs.no_main_app_files"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.mainAppItems) { item in
                        NavigationLink {
                            LogPreviewView(viewModel: LogPreviewViewModel(fileURL: item.url))
                        } label: {
                            Text(item.url.lastPathComponent)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            } header: {
                Text(L10n.string("logs.section_main_app"))
            } footer: {
                Text(L10n.string("logs.section_main_app_footer"))
            }

            Section {
                if viewModel.shareItems.isEmpty {
                    Text(L10n.string("logs.no_share_files"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.shareItems) { item in
                        NavigationLink {
                            LogPreviewView(viewModel: LogPreviewViewModel(fileURL: item.url))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .font(.system(.body, design: .monospaced))
                                Text(L10n.string("logs.share_extension_badge"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.string("logs.section_share_extension"))
            } footer: {
                Text(L10n.string("logs.section_share_extension_footer"))
            }
        }
        .navigationTitle("logs.files")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .onAppear { viewModel.reload() }
        .refreshable { viewModel.reload() }
    }
}
