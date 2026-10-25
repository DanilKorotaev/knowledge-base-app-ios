import Foundation

/// Share Extension config: App Group URL + Keychain JWT only (no baked Info.plist secrets).
enum ShareConfiguration {
    static func apiBaseURL() -> URL? {
        guard let shared = AppGroupContainer.sharedDefaults?
            .string(forKey: "kbapp.config.api_base_url")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !shared.isEmpty,
            let url = URL(string: shared)
        else {
            return nil
        }
        return url
    }

    static func authToken() -> String? {
        KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
