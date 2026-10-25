import SwiftUI

/// Settings: pick or create the Nextcloud folder used as the knowledge-base root (`kb_folder`).
struct KnowledgeBaseFolderSettingsView: View {
    @Bindable private var authSession = AuthSessionStore.shared

    @State private var folders: [AuthNcFolderDTO] = []
    @State private var current: String = "/"
    @State private var hasAppPassword = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var newFolderName = ""

    var body: some View {
        List {
            Section {
                if isLoading && folders.isEmpty {
                    ProgressView()
                } else {
                    ForEach(folders) { folder in
                        Button {
                            Task { await selectFolder(folder.path) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folderDisplayName(folder))
                                        .foregroundStyle(.primary)
                                    if folder.path != folder.name {
                                        Text(folder.path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if folder.path == current {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("settings.kb_folder.row.\(folder.path)")
                    }
                }
            } header: {
                Text("settings.kb_folder.section")
            } footer: {
                Text(footerText)
            }

            Section {
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
        .refreshable { await reload() }
        .task { await reload() }
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

    private var footerText: String {
        if !hasAppPassword {
            return String(localized: "settings.kb_folder.no_app_password")
        }
        return String(localized: "settings.kb_folder.footer")
    }

    private func folderDisplayName(_ folder: AuthNcFolderDTO) -> String {
        if folder.path == "/" {
            return String(localized: "settings.kb_folder.home")
        }
        return folder.name
    }

    @MainActor
    private func reload() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            let token = try await authSession.validAccessToken()
            let payload = try await client.listNcFolders(accessToken: token)
            folders = payload.folders
            current = payload.current
            hasAppPassword = payload.hasNcAppPassword
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
            await reload()
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
            let payload = try await client.createNcFolder(accessToken: token, name: name, select: true)
            folders = payload.folders
            current = payload.current
            hasAppPassword = payload.hasNcAppPassword
            showCreateSheet = false
            await authSession.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
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
