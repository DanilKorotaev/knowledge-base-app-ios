import Foundation

/// Non-secret runtime configuration. API base URL is not a secret; **auth token must move to Keychain** before any real deployment.
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
        return UserDefaults.standard.string(forKey: userDefaultsKey(for: key))?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func url(for key: String) -> URL? {
        guard let raw = string(for: key) else { return nil }
        return URL(string: raw)
    }

    static func setUserString(_ value: String?, for key: String) {
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
