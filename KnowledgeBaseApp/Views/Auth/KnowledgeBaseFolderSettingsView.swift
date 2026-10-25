import SwiftUI

/// Settings: browse Nextcloud folders (drill-down) and pick `kb_folder`.
struct KnowledgeBaseFolderSettingsView: View {
    @Bindable private var authSession = AuthSessionStore.shared

    @State private var folders: [AuthNcFolderDTO] = []
    @State private var current: String = "/"
    @State private var browsePath: String = "/"
    @State private var parentPath: String?
    @State private var hasAppPassword = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newFolderName = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(browseDisplayName)
                            .foregroundStyle(.primary)
                        if browsePath != "/" {
                            Text(browsePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if browsePath == current {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .accessibilityIdentifier("settings.kb_folder.browse")

                if let parentPath {
                    Button {
                        Task { await reload(path: parentPath) }
                    } label: {
                        Label("settings.kb_folder.up", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || isSaving)
                    .accessibilityIdentifier("settings.kb_folder.up")
                }
            } header: {
                Text("settings.kb_folder.section")
            } footer: {
                Text(footerText)
            }

            Section {
                if isLoading && folders.isEmpty {
                    ProgressView()
                } else if folders.isEmpty {
                    Text("settings.kb_folder.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(folders) { folder in
                        Button {
                            Task { await reload(path: folder.path) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(folder.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if folder.path == current {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || isSaving)
                        .accessibilityIdentifier("settings.kb_folder.row.\(folder.path)")
                    }
                }
            }

            Section {
                Button {
                    Task { await selectFolder(browsePath) }
                } label: {
                    Text(useThisFolderTitle)
                }
                .disabled(!hasAppPassword || isSaving || browsePath == current)
                .accessibilityIdentifier("settings.kb_folder.use")

                Button("settings.kb_folder.create") {
                    newFolderName = ""
                    showCreateSheet = true
                }
                .disabled(!hasAppPassword || isSaving)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.kb_folder.title")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload(path: browsePath) }
        .task {
            let start = authSession.currentUser?.kbFolder ?? "/"
            await reload(path: start)
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    TextField("settings.kb_folder.name_placeholder", text: $newFolderName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .navigationTitle("settings.kb_folder.create")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.create") {
                            Task { await createFolder() }
                        }
                        .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .overlay {
            if isSaving {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var browseDisplayName: String {
        if browsePath == "/" {
            return String(localized: "settings.kb_folder.home")
        }
        return browsePath.split(separator: "/").last.map(String.init) ?? browsePath
    }

    private var useThisFolderTitle: String {
        if browsePath == "/" {
            return String(localized: "settings.kb_folder.use_home")
        }
        return String(localized: "settings.kb_folder.use_this")
    }

    private var footerText: String {
        if !hasAppPassword {
            return String(localized: "settings.kb_folder.no_app_password")
        }
        return String(localized: "settings.kb_folder.footer")
    }

    @MainActor
    private func reload(path: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            let token = try await authSession.validAccessToken()
            let payload = try await client.listNcFolders(accessToken: token, path: path)
            apply(payload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func selectFolder(_ path: String) async {
        guard path != current else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let client = try makeClient()
            let token = try await authSession.validAccessToken()
            let user = try await client.patchMe(accessToken: token, kbFolder: path)
            authSession.applyUpdatedUser(user)
            current = user.kbFolder ?? path
            await reload(path: browsePath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let client = try makeClient()
            let token = try await authSession.validAccessToken()
            let payload = try await client.createNcFolder(
                accessToken: token,
                name: name,
                parent: browsePath,
                select: true
            )
            apply(payload)
            showCreateSheet = false
            await authSession.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ payload: AuthNcFoldersResponse) {
        folders = payload.folders
        current = payload.current
        browsePath = payload.browsePath
        parentPath = payload.parentPath
        hasAppPassword = payload.hasNcAppPassword
    }

    private func makeClient() throws -> URLSessionAuthAPIClient {
        guard let client = URLSessionAuthAPIClient.makeFromConfiguration() else {
            throw AuthAPIError.missingBaseURL
        }
        return client
    }
}

#Preview {
    NavigationStack {
        KnowledgeBaseFolderSettingsView()
    }
}
