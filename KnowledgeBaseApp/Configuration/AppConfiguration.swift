import Foundation

/// Runtime API configuration: scheme env → Info.plist (build-time Secrets.xcconfig) → Settings/Keychain.
enum AppConfiguration {
    static let environmentPrefix = "KBAPP_"

    enum Keys {
        static let apiBaseURL = "API_BASE_URL"
        static let authToken = "AUTH_TOKEN"
    }

    static func string(for key: String) -> String? {
        let name = environmentPrefix + key
        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        if let builtIn = bundleString(for: key) {
            return builtIn
        }
        if key == Keys.authToken {
            if let kc = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return kc
            }
            let udKey = userDefaultsKey(for: key)
            if let legacy = UserDefaults.standard.string(forKey: udKey)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                KeychainTokenStore.setToken(legacy)
                UserDefaults.standard.removeObject(forKey: udKey)
                return legacy
            }
            return nil
        }
        return UserDefaults.standard.string(forKey: userDefaultsKey(for: key))?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func url(for key: String) -> URL? {
        guard let raw = string(for: key) else { return nil }
        return URL(string: raw)
    }

    static func setUserString(_ value: String?, for key: String) {
        if key == Keys.authToken {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            KeychainTokenStore.setToken(trimmed.isEmpty ? nil : trimmed)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: key))
            return
        }
        let udKey = userDefaultsKey(for: key)
        if let value {
            UserDefaults.standard.set(value, forKey: udKey)
        } else {
            UserDefaults.standard.removeObject(forKey: udKey)
        }
    }

    private static func userDefaultsKey(for key: String) -> String {
        "kbapp.config.\(key.lowercased())"
    }

    /// Values from Info.plist (filled via `Config/Secrets.xcconfig` → `INFOPLIST_KEY_*` at build time).
    private static func bundleString(for key: String) -> String? {
        let plistKey: String
        switch key {
        case Keys.apiBaseURL:
            plistKey = "KBAppAPIBaseURL"
        case Keys.authToken:
            plistKey = "KBAppAuthToken"
        default:
            return nil
        }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
