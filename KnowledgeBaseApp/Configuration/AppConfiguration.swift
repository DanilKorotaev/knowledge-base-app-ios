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
            if let legacy = legacyUserDefaultsString(for: key) {
                KeychainTokenStore.setToken(legacy)
                UserDefaults.standard.removeObject(forKey: "kbapp.config.auth_token")
                return legacy
            }
            return nil
        }
        return userDefaultsString(for: key)
    }

    static func url(for key: String) -> URL? {
        guard let raw = string(for: key) else { return nil }
        return URL(string: raw)
    }

    static func setUserString(_ value: String?, for key: String) {
        if key == Keys.authToken {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            KeychainTokenStore.setToken(trimmed.isEmpty ? nil : trimmed)
            UserDefaults.standard.removeObject(forKey: "kbapp.config.auth_token")
            return
        }
        let storageKey = userDefaultsStorageKey(for: key)
        if key == Keys.apiBaseURL {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                UserDefaultsService.shared.set(trimmed, forKey: .apiBaseURL)
                AppGroupContainer.sharedDefaults?.set(trimmed, forKey: UserDefaultsKey.apiBaseURL.rawValue)
            } else {
                UserDefaultsService.shared.removeObject(forKey: .apiBaseURL)
                AppGroupContainer.sharedDefaults?.removeObject(forKey: UserDefaultsKey.apiBaseURL.rawValue)
            }
            return
        }
        if let value {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaultsService.shared.set(trimmed.nilIfEmpty, forKey: storageKey)
        } else {
            UserDefaultsService.shared.removeObject(forKey: storageKey)
        }
    }

    private static func userDefaultsString(for key: String) -> String? {
        let storageKey: UserDefaultsKey
        if key == Keys.apiBaseURL {
            storageKey = .apiBaseURL
            AppGroupContainer.migrateUserDefaultsValue(forKey: storageKey.rawValue)
            if let shared = AppGroupContainer.sharedDefaults?
                .string(forKey: storageKey.rawValue)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty {
                return shared
            }
        } else if key == Keys.authToken {
            return nil
        } else {
            storageKey = UserDefaultsKey(userDefaultsStorageKey(for: key))
        }
        return UserDefaultsService.shared.string(forKey: storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func userDefaultsStorageKey(for key: String) -> String {
        "kbapp.config.\(key.lowercased())"
    }

    private static func legacyUserDefaultsString(for key: String) -> String? {
        UserDefaults.standard.string(forKey: "kbapp.config.\(key.lowercased())")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
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
