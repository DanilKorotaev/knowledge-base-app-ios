import SwiftUI

struct SettingsView: View {
    @State private var apiBaseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL) ?? ""
    @State private var authToken: String = AppConfiguration.string(for: AppConfiguration.Keys.authToken) ?? ""
    @State private var voiceDefaultTitle: String?
    @State private var voiceDefaultExpiry: String?
    @Bindable private var languageStore = AppLanguageStore.shared

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
                TextField("API base URL (https://…)", text: $apiBaseURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                SecureField("Bearer token (dev only)", text: $authToken)
            } header: {
                Text("KB App API")
            } footer: {
                Text(
                    "Matches env vars KBAPP_API_BASE_URL and KBAPP_AUTH_TOKEN. The bearer token is stored in the Keychain when you tap Save."
                )
            }

            Section {
                Button("Save") {
                    let trimmedURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    AppConfiguration.setUserString(trimmedURL.nilIfEmpty, for: AppConfiguration.Keys.apiBaseURL)
                    AppConfiguration.setUserString(trimmedToken.nilIfEmpty, for: AppConfiguration.Keys.authToken)
                }
            }

            Section {
                if let voiceDefaultTitle {
                    LabeledContent("Session", value: voiceDefaultTitle)
                    if let voiceDefaultExpiry {
                        LabeledContent("Expires", value: voiceDefaultExpiry)
                    } else {
                        LabeledContent("Expires", value: "No limit")
                    }
                    Button("Clear voice default", role: .destructive) {
                        DefaultVoiceSessionStore.shared.clear()
                        WatchVoiceSessionContextSync.shared.publish(nil)
                        reloadVoiceDefaultSummary()
                    }
                } else {
                    Text("Not set — use “Default for voice” on a session in the list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice routing")
            } footer: {
                Text("When no chat is open, the mic bar sends to this session. Optional TTL resets automatically.")
            }

            Section {
                NavigationLink("Manage offline cache") {
                    OfflineCacheManagementView()
                }
            } header: {
                Text("Offline")
            } footer: {
                Text("Images and voice messages you open are saved locally for offline viewing.")
            }

            Section("Developer") {
                NavigationLink("Debug menu") {
                    DebugMenuView()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadVoiceDefaultSummary()
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
