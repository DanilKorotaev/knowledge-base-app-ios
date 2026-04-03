import SwiftUI

struct SettingsView: View {
    @State private var apiBaseURL: String = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL) ?? ""
    @State private var authToken: String = AppConfiguration.string(for: AppConfiguration.Keys.authToken) ?? ""

    var body: some View {
        Form {
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
                    "Matches env vars KBAPP_API_BASE_URL and KBAPP_AUTH_TOKEN. Store tokens in Keychain before production."
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
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
