import SwiftUI

struct ChangedFilesView: View {
    let filesClient: FilesAPIClientProtocol
    @State private var files: [KBChangedFile] = []
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && files.isEmpty {
                ProgressView("common.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                ContentUnavailableView(
                    "main.could_not_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if files.isEmpty {
                ContentUnavailableView(
                    "files.no_changes",
                    systemImage: "doc.text",
                    description: Text("files.changed_empty")
                )
            } else {
                List(files) { file in
                    NavigationLink {
                        FileDiffView(file: file, filesClient: filesClient) {
                            Task { await load() }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.path)
                                .font(.headline)
                                .lineLimit(2)
                            Text(file.changeKind)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("files.changed_title")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            files = try await filesClient.fetchChangedFiles()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ChangedFilesView(filesClient: StubFilesAPIClient())
    }
}
