import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum SettingsRoute: Hashable {
    case offlineCache
}

struct SettingsView: View {
    @State private var apiBaseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL) ?? ""
    @State private var authToken: String = AppConfiguration.string(for: AppConfiguration.Keys.authToken) ?? ""
    @State private var voiceDefaultTitle: String?
    @State private var voiceDefaultExpiry: String?
    @State private var didCopyVersion = false
    @Bindable private var languageStore = AppLanguageStore.shared
    @State private var debugQuickActions = DebugQuickActionsController.shared

    private var clientMeta: KBClientMetadata { KBClientMetadata.current }

    var body: some View {
        Form {
            Section {
                Picker("settings.language", selection: languagePreferenceBinding) {
                    Text("settings.language.system").tag(AppLanguagePreference.system)
                    Text("settings.language.english").tag(AppLanguagePreference.english)
                    Text("settings.language.russian").tag(AppLanguagePreference.russian)
                }
            } header: {
                Text("settings.language")
            }

            Section {
                TextField("settings.api_base_url", text: $apiBaseURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                SecureField("settings.auth_token", text: $authToken)
            } header: {
                Text("settings.api_section")
            } footer: {
                Text("settings.api_footer")
            }

            Section {
                Button("common.save") {
                    let trimmedURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    AppConfiguration.setUserString(trimmedURL.nilIfEmpty, for: AppConfiguration.Keys.apiBaseURL)
                    AppConfiguration.setUserString(trimmedToken.nilIfEmpty, for: AppConfiguration.Keys.authToken)
                }
            }

            Section {
                if let voiceDefaultTitle {
                    LabeledContent("common.session", value: voiceDefaultTitle)
                    if let voiceDefaultExpiry {
                        LabeledContent("settings.voice_expires", value: voiceDefaultExpiry)
                    } else {
                        LabeledContent("settings.voice_expires", value: L10n.string("settings.voice_no_limit"))
                    }
                    Button("settings.clear_voice_default", role: .destructive) {
                        DefaultVoiceSessionStore.shared.clear()
                        WatchVoiceSessionContextSync.shared.publish(nil)
                        reloadVoiceDefaultSummary()
                    }
                } else {
                    Text("settings.voice_not_set")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("settings.voice_routing")
            } footer: {
                Text("settings.voice_footer")
            }

            Section {
                NavigationLink(value: SettingsRoute.offlineCache) {
                    Text("settings.manage_offline_cache")
                }
            } header: {
                Text("settings.offline")
            } footer: {
                Text("settings.offline_footer")
            }

            Section {
                Button {
                    copyVersionToPasteboard()
                } label: {
                    HStack {
                        Text("settings.about.version")
                        Spacer()
                        Text(clientMeta.versionBuildLabel)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .accessibilityLabel(Text("settings.about.version"))
                .accessibilityValue(Text(clientMeta.versionBuildLabel))
            } header: {
                Text("settings.about")
            } footer: {
                Text(didCopyVersion ? "settings.about.copied" : "settings.about.copy_hint")
            }

            Section("settings.developer") {
                Button {
                    debugQuickActions.presentDebugMenuFromSettings()
                } label: {
                    HStack {
                        Text("settings.debug_menu")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("settings.developer_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadVoiceDefaultSummary()
        }
    }

    private func copyVersionToPasteboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = clientMeta.versionBuildLabel
        #endif
        didCopyVersion = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            didCopyVersion = false
        }
    }

    private func reloadVoiceDefaultSummary() {
        guard let preference = DefaultVoiceSessionStore.shared.load(), preference.isValid() else {
            voiceDefaultTitle = nil
            voiceDefaultExpiry = nil
            return
        }
        voiceDefaultTitle = preference.sessionTitle
        if let expiresAt = preference.expiresAt {
            voiceDefaultExpiry = expiresAt.formatted(date: .omitted, time: .shortened)
        } else {
            voiceDefaultExpiry = nil
        }
    }

    private var languagePreferenceBinding: Binding<AppLanguagePreference> {
        Binding(
            get: { languageStore.override },
            set: { languageStore.setOverride($0) }
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
