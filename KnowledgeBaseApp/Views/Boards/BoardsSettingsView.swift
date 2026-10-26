import SwiftUI

struct BoardsSettingsView: View {
    @State private var overviewEnabled = BoardsPreferences.isOverviewEnabled
    @State private var presets: [KBBoardPreset] = []
    @State private var isLoadingPresets = false
    @State private var presetsError: String?
    @State private var busyPresetId: String?

    private var client: BoardsAPIClientProtocol {
        URLSessionBoardsAPIClient() ?? StubBoardsAPIClient()
    }

    var body: some View {
        Form {
            Section {
                Toggle("boards.settings.enable", isOn: $overviewEnabled)
                    .onChange(of: overviewEnabled) { _, newValue in
                        BoardsPreferences.isOverviewEnabled = newValue
                    }
            } footer: {
                Text("boards.settings.enable_footer")
            }

            Section {
                if isLoadingPresets && presets.isEmpty {
                    ProgressView()
                } else if let presetsError, presets.isEmpty {
                    Text(presetsError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(presets) { preset in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: preset.systemImageName)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title)
                                if let subtitle = preset.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let surface = preset.surface, !surface.isEmpty {
                                    Text(surface.capitalized)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            if busyPresetId == preset.id {
                                ProgressView()
                            } else if preset.installed {
                                Button("boards.presets.uninstall", role: .destructive) {
                                    Task { await uninstall(preset) }
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("boards.presets.install") {
                                    Task { await install(preset) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .accessibilityIdentifier("boards.preset.\(preset.id)")
                    }
                }
            } header: {
                Text("boards.presets.title")
            } footer: {
                Text("boards.presets.footer")
            }
        }
        .navigationTitle("boards.settings.title")
        .task {
            await reloadPresets()
        }
        .refreshable {
            await reloadPresets()
        }
    }

    @MainActor
    private func reloadPresets() async {
        isLoadingPresets = true
        presetsError = nil
        defer { isLoadingPresets = false }
        do {
            presets = try await client.fetchPresets()
        } catch {
            presetsError = error.localizedDescription
        }
    }

    @MainActor
    private func install(_ preset: KBBoardPreset) async {
        busyPresetId = preset.id
        defer { busyPresetId = nil }
        do {
            _ = try await client.installPreset(id: preset.id)
            await reloadPresets()
        } catch {
            presetsError = error.localizedDescription
        }
    }

    @MainActor
    private func uninstall(_ preset: KBBoardPreset) async {
        busyPresetId = preset.id
        defer { busyPresetId = nil }
        do {
            try await client.uninstallPreset(id: preset.id)
            await reloadPresets()
        } catch {
            presetsError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        BoardsSettingsView()
    }
}
