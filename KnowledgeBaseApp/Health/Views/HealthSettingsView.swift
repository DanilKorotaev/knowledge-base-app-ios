import SwiftUI

struct HealthSettingsView: View {
    @State private var viewModel = HealthSyncViewModel()
    @State private var folderDraft: String = "HealthData"
    @State private var syncEnabled = HealthSyncPreferences.isSyncEnabled

    var body: some View {
        Form {
            Section {
                Toggle("health.settings.enable", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, newValue in
                        HealthSyncPreferences.isSyncEnabled = newValue
                    }
            } footer: {
                Text("health.settings.enable_footer")
            }

            Section {
                TextField("health.settings.folder", text: $folderDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("common.save") {
                    Task { await viewModel.updateHealthFolder(folderDraft) }
                }
            } header: {
                Text("health.settings.folder_section")
            } footer: {
                Text("health.settings.folder_footer")
            }

            Section {
                LabeledContent("health.settings.availability") {
                    Text(viewModel.isHealthDataAvailable ? "health.settings.available" : "health.settings.unavailable")
                }
                Button("health.request_access") {
                    Task { await viewModel.requestAuthorization() }
                }
                .disabled(!viewModel.isHealthDataAvailable)
            }
        }
        .navigationTitle("health.settings.title")
        .task {
            await viewModel.refresh()
            folderDraft = viewModel.healthDataRelative
        }
        .onChange(of: viewModel.healthDataRelative) { _, newValue in
            folderDraft = newValue
        }
        .alert(
            viewModel.presentedAlert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.presentedAlert != nil },
                set: { if !$0 { viewModel.dismissAlert() } }
            )
        ) {
            Button("common.ok", role: .cancel) {
                viewModel.dismissAlert()
            }
        } message: {
            Text(viewModel.presentedAlert?.message ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        HealthSettingsView()
    }
}
