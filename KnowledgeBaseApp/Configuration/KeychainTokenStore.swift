import Foundation
import Security

/// Stores the KB App API bearer token in the Keychain (not UserDefaults).
/// Uses a shared access group so the Share Extension can reuse the main-app token.
enum KeychainTokenStore {
    private static let service = "com.coredan.KnowledgeBaseApp.authToken"
    private static let account = "KBAPP_AUTH_TOKEN"
    private static let accessGroup = AppGroupIdentifiers.keychainAccessGroup

    static func setToken(_ value: String?) {
        deleteToken(includeLegacy: true)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecMissingEntitlement {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func token() -> String? {
        if let shared = readToken(useAccessGroup: true) {
            return shared
        }
        guard let legacy = readToken(useAccessGroup: false) else { return nil }
        // Promote legacy (app-only) item into the shared access group.
        setToken(legacy)
        return legacy
    }

    private static func readToken(useAccessGroup: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
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

    private static func deleteToken(includeLegacy: Bool) {
        var sharedQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        SecItemDelete(sharedQuery as CFDictionary)

        if includeLegacy {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(legacyQuery as CFDictionary)
        }
    }
}
