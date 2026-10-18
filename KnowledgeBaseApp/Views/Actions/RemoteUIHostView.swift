import SwiftUI

/// Presents a stack of remote Structured UI documents (`remote_ui` AppAction).
struct RemoteUIHostView: View {
    let initialURL: String
    let title: String?

    @Environment(\.dismiss) private var dismiss
    @State private var path: [RemoteUIPage] = []
    @State private var rootPage: RemoteUIPage?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let rootPage {
                    pageView(rootPage)
                } else if isLoading {
                    ProgressView("remote_ui.loading")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "remote_ui.failed_title",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorText ?? L10n.string("remote_ui.failed_hint"))
                    )
                }
            }
            .navigationTitle(title ?? L10n.string("remote_ui.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .navigationDestination(for: RemoteUIPage.self) { page in
                pageView(page)
                    .navigationTitle(page.title ?? L10n.string("remote_ui.title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            await loadRoot()
        }
    }

    @ViewBuilder
    private func pageView(_ page: RemoteUIPage) -> some View {
        ScrollView {
            StructuredUIPanelView(
                document: page.document,
                isSending: false,
                isInteractive: true,
                attachmentLoader: nil,
                onFullscreenImage: nil,
                onAction: { _, _, _ in },
                onAppAction: { action, node in
                    handle(action: action, from: node)
                }
            )
            .padding()
        }
    }

    private func handle(action: KBAppAction, from node: KBStructuredUINode) {
        if action.type == "remote_ui" {
            guard let url = action.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty
            else { return }
            Task { await push(url: url, title: action.title) }
            return
        }
        KBAppActionCenter.shared.perform(action)
    }

    private func loadRoot() async {
        isLoading = true
        errorText = nil
        do {
            let document = try await makeFetcher().fetchDocument(from: initialURL)
            rootPage = RemoteUIPage(url: initialURL, title: title, document: document)
        } catch {
            errorText = error.localizedDescription
            rootPage = nil
        }
        isLoading = false
    }

    private func push(url: String, title: String?) async {
        do {
            let document = try await makeFetcher().fetchDocument(from: url)
            path.append(RemoteUIPage(url: url, title: title, document: document))
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func makeFetcher() -> RemoteUIFetcher {
        RemoteUIFetcher(
            apiBaseURL: AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL),
            authToken: AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        )
    }
}

struct RemoteUIPage: Hashable, Identifiable {
    let id = UUID()
    let url: String
    let title: String?
    let document: KBStructuredUIDocument

    static func == (lhs: RemoteUIPage, rhs: RemoteUIPage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
