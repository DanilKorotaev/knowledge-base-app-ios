import Foundation
import Security

/// Persisted multi-account sessions. Offline caches stay per `(server, userId)` until sign-out.
struct SavedAccount: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: String
    var apiBaseURL: String
    var userId: Int
    var login: String
    var accessToken: String
    var refreshToken: String?
    var vaultRootRelative: String?
    var kbFolder: String?

    static func makeId(apiBaseURL: String, userId: Int) -> String {
        let host = OfflineCacheScope.hostKey(from: URL(string: apiBaseURL))
        return "\(host)|u\(userId)"
    }
}

/// Keychain-backed list of saved accounts + UserDefaults active pointer.
enum SavedAccountsStore {
    private static let service = "com.coredan.KnowledgeBaseApp.savedAccounts"
    private static let account = "KBAPP_SAVED_ACCOUNTS"
    private static let activeIdKey = "kb.auth.active_account_id"
    private static let accessGroup = AppGroupIdentifiers.keychainAccessGroup

    static var activeAccountId: String? {
        get { UserDefaults.standard.string(forKey: activeIdKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: activeIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeIdKey)
            }
        }
    }

    static func loadAll() -> [SavedAccount] {
        guard let data = readBlob(),
              let list = try? JSONDecoder().decode([SavedAccount].self, from: data) else {
            return []
        }
        return list.sorted { $0.login.localizedCaseInsensitiveCompare($1.login) == .orderedAscending }
    }

    static func account(id: String) -> SavedAccount? {
        loadAll().first { $0.id == id }
    }

    static func upsert(_ account: SavedAccount) {
        var list = loadAll()
        if let index = list.firstIndex(where: { $0.id == account.id }) {
            list[index] = account
        } else {
            list.append(account)
        }
        writeAll(list)
        activeAccountId = account.id
    }

    static func updateTokens(id: String, accessToken: String, refreshToken: String?) {
        var list = loadAll()
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].accessToken = accessToken
        list[index].refreshToken = refreshToken
        writeAll(list)
    }

    @discardableResult
    static func remove(id: String) -> [SavedAccount] {
        var list = loadAll()
        list.removeAll { $0.id == id }
        writeAll(list)
        if activeAccountId == id {
            activeAccountId = list.first?.id
        }
        return list
    }

    static func clearAll() {
        writeAll([])
        activeAccountId = nil
    }

    // MARK: - Keychain blob

    private static func writeAll(_ accounts: [SavedAccount]) {
        deleteBlob()
        guard let data = try? JSONEncoder().encode(accounts), !accounts.isEmpty else { return }
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

    private static func readBlob() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecMissingEntitlement || status == errSecItemNotFound {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &item)
        }
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func deleteBlob() {
        let shared: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        SecItemDelete(shared as CFDictionary)
        let legacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(legacy as CFDictionary)
    }
}
