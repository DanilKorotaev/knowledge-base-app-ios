import Foundation

/// Lightweight config for the Share Extension (Keychain + App Group + Info.plist).
enum ShareConfiguration {
    static func apiBaseURL() -> URL? {
        if let shared = AppGroupContainer.sharedDefaults?
            .string(forKey: "kbapp.config.api_base_url")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !shared.isEmpty,
           let url = URL(string: shared) {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "KBAppAPIBaseURL") as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }
        return nil
    }

    static func authToken() -> String? {
        if let kc = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines), !kc.isEmpty {
            return kc
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "KBAppAuthToken") as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
