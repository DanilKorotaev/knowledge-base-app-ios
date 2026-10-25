import Foundation

/// Runtime API configuration: optional scheme env → onboarding/Settings URL + Keychain JWT.
///
/// Build-time Info.plist / Secrets.xcconfig values are intentionally ignored so TestFlight
/// never silently overrides a server chosen at login.
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
        if key == Keys.authToken {
            return KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
        let storageKey = userDefaultsStorageKey(for: key)
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
