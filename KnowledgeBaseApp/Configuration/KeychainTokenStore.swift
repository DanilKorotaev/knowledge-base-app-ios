import Foundation
import Security

/// Stores KB App API tokens in the Keychain (not UserDefaults).
/// Uses a shared access group so the Share Extension can reuse the main-app access token.
enum KeychainTokenStore {
    private static let service = "com.coredan.KnowledgeBaseApp.authToken"
    private static let accessAccount = "KBAPP_AUTH_TOKEN"
    private static let refreshAccount = "KBAPP_REFRESH_TOKEN"
    /// Legacy account name — still read/cleared for migration.
    private static let legacyAccessAccount = "KBAPP_AUTH_TOKEN"
    private static let accessGroup = AppGroupIdentifiers.keychainAccessGroup

    // MARK: - Access token (Bearer)

    static func setToken(_ value: String?) {
        setSecret(value, account: accessAccount)
    }

    static func token() -> String? {
        if let shared = readSecret(account: accessAccount, useAccessGroup: true) {
            return shared
        }
        guard let legacy = readSecret(account: legacyAccessAccount, useAccessGroup: false) else { return nil }
        // Promote legacy (app-only) item into the shared access group.
        setToken(legacy)
        return legacy
    }

    // MARK: - Refresh token

    static func setRefreshToken(_ value: String?) {
        setSecret(value, account: refreshAccount)
    }

    static func refreshToken() -> String? {
        if let shared = readSecret(account: refreshAccount, useAccessGroup: true) {
            return shared
        }
        return readSecret(account: refreshAccount, useAccessGroup: false)
    }

    // MARK: - Session

    static func setSession(accessToken: String, refreshToken: String) {
        setToken(accessToken)
        setRefreshToken(refreshToken)
    }

    static func clearSession() {
        setToken(nil)
        setRefreshToken(nil)
    }

    // MARK: - Internals

    private static func setSecret(_ value: String?, account: String) {
        deleteSecret(account: account, includeLegacy: true)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccessGroup as String: accessGroup
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            SecItemAdd(query as CFDictionary, nil)
        }
        // Post-refresh API retries must not re-read a mid-delete Keychain window:
        // KBHTTPTransport forces the new access token on the retry request.
    }

    private static func readSecret(account: String, useAccessGroup: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func deleteSecret(account: String, includeLegacy: Bool) {
        let sharedQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(sharedQuery as CFDictionary)

        if includeLegacy {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(legacyQuery as CFDictionary)
        }
    }
}
