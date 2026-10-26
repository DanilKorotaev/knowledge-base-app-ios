import Foundation
import Observation

/// Owns login session: Keychain tokens + optional cached user profile.
/// Supports multiple saved accounts; offline caches stay until full sign-out.
@Observable
final class AuthSessionStore {
    static let shared = AuthSessionStore()

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var currentUser: AuthUserDTO?
    private(set) var isAuthenticated: Bool = false
    private(set) var savedAccounts: [SavedAccount] = []

    /// Serializes concurrent 401→refresh attempts.
    private let refreshLock = NSLock()
    private var refreshTask: Task<String, Error>?

    private init() {
        restoreFromKeychain()
    }

    var mustChangePassword: Bool {
        currentUser?.mustChangePassword == true
    }

    var activeAccountId: String? {
        SavedAccountsStore.activeAccountId
    }

    /// UI tests use stub clients and should skip the login gate (unless forced).
    var shouldPresentLoginGate: Bool {
        if UITestRuntime.forceLoginGate { return true }
        if UITestRuntime.isUITesting { return false }
        return !isAuthenticated
    }

    func restoreFromKeychain() {
        savedAccounts = SavedAccountsStore.loadAll()
        migrateLegacySessionIfNeeded()

        if let activeId = SavedAccountsStore.activeAccountId,
           let account = SavedAccountsStore.account(id: activeId) {
            applySavedAccount(account, notify: false)
            return
        }

        let access = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refresh = KeychainTokenStore.refreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        accessToken = access?.nilIfEmpty
        refreshToken = refresh?.nilIfEmpty
        isAuthenticated = accessToken != nil
        if currentUser == nil, let access, let sub = Self.jwtSubjectUserId(access) {
            currentUser = AuthUserDTO(
                id: sub,
                login: UserDefaults.standard.string(forKey: Self.cachedLoginKey) ?? "user",
                email: nil,
                role: nil,
                mustChangePassword: false,
                cursorIsolation: nil,
                vaultRootRelative: nil,
                nextcloudUsername: nil,
                kbFolder: nil,
                hasNcAppPassword: nil
            )
        }
        rebindCaches()
        savedAccounts = SavedAccountsStore.loadAll()
    }

    @MainActor
    func applyUpdatedUser(_ user: AuthUserDTO) {
        currentUser = user
        UserDefaults.standard.set(user.login, forKey: Self.cachedLoginKey)
        if var account = currentSavedAccount() {
            account.login = user.login
            account.vaultRootRelative = user.vaultRootRelative
            account.kbFolder = user.kbFolder
            SavedAccountsStore.upsert(account)
            savedAccounts = SavedAccountsStore.loadAll()
        }
        rebindCaches()
    }

    @MainActor
    func apply(tokens: AuthTokenResponse) {
        KeychainTokenStore.setSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        AppConfiguration.setUserString(tokens.accessToken, for: AppConfiguration.Keys.authToken)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        currentUser = tokens.user
        UserDefaults.standard.set(tokens.user.login, forKey: Self.cachedLoginKey)
        isAuthenticated = true
        persistCurrentAsSavedAccount()
        rebindCaches()
        PushNotificationService.shared.onAuthenticated()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    @MainActor
    func applyAccessTokenOnly(_ token: String) {
        // Legacy / Settings paste path — no refresh.
        KeychainTokenStore.setToken(token)
        KeychainTokenStore.setRefreshToken(nil)
        AppConfiguration.setUserString(token, for: AppConfiguration.Keys.authToken)
        accessToken = token
        refreshToken = nil
        if let sub = Self.jwtSubjectUserId(token) {
            currentUser = AuthUserDTO(
                id: sub,
                login: UserDefaults.standard.string(forKey: Self.cachedLoginKey) ?? "user",
                email: nil,
                role: nil,
                mustChangePassword: false,
                cursorIsolation: nil,
                vaultRootRelative: nil,
                nextcloudUsername: nil,
                kbFolder: nil,
                hasNcAppPassword: nil
            )
        }
        isAuthenticated = true
        persistCurrentAsSavedAccount()
        rebindCaches()
        PushNotificationService.shared.onAuthenticated()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    /// Switch to another saved account without wiping caches.
    @MainActor
    func switchToAccount(id: String) async {
        guard let account = SavedAccountsStore.account(id: id) else { return }
        if let current = currentSavedAccount(), current.id != account.id {
            persistCurrentAsSavedAccount()
        }
        await PushNotificationService.shared.unregisterFromServer()
        applySavedAccount(account, notify: true)
        PushNotificationService.shared.onAuthenticated()
    }

    /// Park the current session and show login to add another account (caches kept).
    @MainActor
    func beginAddAccount() async {
        persistCurrentAsSavedAccount()
        await PushNotificationService.shared.unregisterFromServer()
        KeychainTokenStore.clearSession()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.authToken)
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        SavedAccountsStore.activeAccountId = nil
        // Keep disk caches for previous account; rebind to anonymous until new login.
        rebindCaches()
        savedAccounts = SavedAccountsStore.loadAll()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    /// Full sign-out of the current account: revoke tokens and wipe that account’s offline cache.
    @MainActor
    func clear(logoutRemote: Bool = true) async {
        let access = accessToken
        let refresh = refreshToken
        let signingOutUserId = currentUser?.id
        let signingOutAccountId = currentSavedAccount()?.id
        let apiBase = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL)

        await PushNotificationService.shared.unregisterFromServer()
        if logoutRemote, let client = URLSessionAuthAPIClient.makeFromConfiguration() {
            try? await client.logout(accessToken: access, refreshToken: refresh)
        }

        wipeOfflineCache(apiBaseURL: apiBase, userId: signingOutUserId)

        if let signingOutAccountId {
            savedAccounts = SavedAccountsStore.remove(id: signingOutAccountId)
        }

        if let next = savedAccounts.first {
            applySavedAccount(next, notify: true)
            PushNotificationService.shared.onAuthenticated()
            return
        }

        KeychainTokenStore.clearSession()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.authToken)
        UserDefaults.standard.removeObject(forKey: Self.cachedLoginKey)
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        SavedAccountsStore.activeAccountId = nil
        rebindCaches()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    /// Drop local credentials when access/refresh can no longer be renewed (show login).
    func invalidateLocalSession(reason: String) async {
        let shouldClear = await MainActor.run { () -> Bool in
            guard isAuthenticated else { return false }
            makeLogger(tags: [.network]).releaseInfo("Auth session invalidated: \(reason)")
            return true
        }
        guard shouldClear else { return }
        await clear(logoutRemote: false)
    }

    private func rebindCaches() {
        let userId = currentUser?.id
        FileOfflineCacheStore.shared.rebindToCurrentUser(userId: userId)
        FileAttachmentDiskCache.shared.rebindToCurrentUser(userId: userId)
    }

    private func wipeOfflineCache(apiBaseURL: URL?, userId: Int?) {
        let root = OfflineCacheScope.storeRoot(apiBaseURL: apiBaseURL, userId: userId)
        try? FileManager.default.removeItem(at: root)
    }

    private func currentSavedAccount() -> SavedAccount? {
        guard let user = currentUser,
              let base = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL) else {
            return nil
        }
        let id = SavedAccount.makeId(apiBaseURL: base, userId: user.id)
        return SavedAccountsStore.account(id: id)
    }

    private func persistCurrentAsSavedAccount() {
        guard let access = accessToken?.nilIfEmpty,
              let user = currentUser,
              let base = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL)?.nilIfEmpty else {
            return
        }
        let account = SavedAccount(
            id: SavedAccount.makeId(apiBaseURL: base, userId: user.id),
            apiBaseURL: base,
            userId: user.id,
            login: user.login,
            accessToken: access,
            refreshToken: refreshToken,
            vaultRootRelative: user.vaultRootRelative,
            kbFolder: user.kbFolder
        )
        SavedAccountsStore.upsert(account)
        savedAccounts = SavedAccountsStore.loadAll()
    }

    private func applySavedAccount(_ account: SavedAccount, notify: Bool) {
        if let url = URL(string: account.apiBaseURL) {
            AppConfiguration.setUserString(url.absoluteString, for: AppConfiguration.Keys.apiBaseURL)
        }
        KeychainTokenStore.setToken(account.accessToken)
        KeychainTokenStore.setRefreshToken(account.refreshToken?.nilIfEmpty)
        AppConfiguration.setUserString(account.accessToken, for: AppConfiguration.Keys.authToken)
        accessToken = account.accessToken
        refreshToken = account.refreshToken?.nilIfEmpty
        currentUser = AuthUserDTO(
            id: account.userId,
            login: account.login,
            email: nil,
            role: nil,
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: account.vaultRootRelative,
            nextcloudUsername: nil,
            kbFolder: account.kbFolder,
            hasNcAppPassword: nil
        )
        UserDefaults.standard.set(account.login, forKey: Self.cachedLoginKey)
        isAuthenticated = true
        SavedAccountsStore.activeAccountId = account.id
        savedAccounts = SavedAccountsStore.loadAll()
        rebindCaches()
        if notify {
            NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
        }
    }

    /// Promote a single Keychain session into the multi-account store (one-time).
    private func migrateLegacySessionIfNeeded() {
        guard SavedAccountsStore.loadAll().isEmpty,
              let access = KeychainTokenStore.token()?.nilIfEmpty,
              let base = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL)?.nilIfEmpty,
              let userId = Self.jwtSubjectUserId(access) else {
            return
        }
        let login = UserDefaults.standard.string(forKey: Self.cachedLoginKey) ?? "user"
        let account = SavedAccount(
            id: SavedAccount.makeId(apiBaseURL: base, userId: userId),
            apiBaseURL: base,
            userId: userId,
            login: login,
            accessToken: access,
            refreshToken: KeychainTokenStore.refreshToken(),
            vaultRootRelative: nil,
            kbFolder: nil
        )
        SavedAccountsStore.upsert(account)
    }

    @MainActor
    func refreshProfile() async {
        guard let access = accessToken, let client = URLSessionAuthAPIClient.makeFromConfiguration() else { return }
        do {
            let user = try await client.me(accessToken: access)
            currentUser = user
            applyUpdatedUser(user)
        } catch {
            // Keep cached user if /me fails (offline).
        }
    }

    /// Returns a valid access token, refreshing when missing or near expiry.
    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let access = accessToken, !access.isEmpty,
           !Self.jwtIsExpiredOrNearExpiry(access, skewSeconds: 60) {
            return access
        }
        return try await refreshAccessToken()
    }

    /// Best-effort renew before the first parallel API calls after cold start.
    func ensureFreshAccessTokenIfNeeded() async {
        guard isAuthenticated else { return }
        guard let access = accessToken, !access.isEmpty else {
            _ = try? await refreshAccessToken()
            return
        }
        guard Self.jwtIsExpiredOrNearExpiry(access, skewSeconds: 60) else { return }
        do {
            _ = try await refreshAccessToken()
        } catch {
            await invalidateLocalSession(reason: "proactive refresh failed: \(error.localizedDescription)")
        }
    }

    func refreshAccessToken() async throws -> String {
        refreshLock.lock()
        if let existing = refreshTask {
            refreshLock.unlock()
            return try await existing.value
        }
        let task = Task<String, Error> {
            guard let refresh = KeychainTokenStore.refreshToken()?.nilIfEmpty else {
                throw AuthAPIError.invalidResponse(
                    statusCode: 401,
                    message: String(localized: "auth.session_expired")
                )
            }
            guard let client = URLSessionAuthAPIClient.makeFromConfiguration() else {
                throw AuthAPIError.missingBaseURL
            }
            let tokens = try await client.refresh(refreshToken: refresh)
            await MainActor.run {
                self.apply(tokens: tokens)
            }
            return tokens.accessToken
        }
        refreshTask = task
        refreshLock.unlock()
        defer {
            refreshLock.lock()
            refreshTask = nil
            refreshLock.unlock()
        }
        return try await task.value
    }
}

extension Notification.Name {
    static let kbAuthSessionDidChange = Notification.Name("kbAuthSessionDidChange")
}

extension AuthSessionStore {
    private static let cachedLoginKey = "kb.auth.cached_login"

    /// Decode JWT `sub` without verifying signature (cache scoping only).
    static func jwtSubjectUserId(_ token: String) -> Int? {
        guard let json = jwtPayloadJSON(token) else { return nil }
        if let sub = json["sub"] as? String { return Int(sub) }
        if let sub = json["sub"] as? Int { return sub }
        return nil
    }

    /// `true` when `exp` is missing, already past, or within `skewSeconds`.
    static func jwtIsExpiredOrNearExpiry(_ token: String, skewSeconds: TimeInterval) -> Bool {
        guard let json = jwtPayloadJSON(token) else { return true }
        let exp: TimeInterval?
        if let value = json["exp"] as? TimeInterval {
            exp = value
        } else if let value = json["exp"] as? Int {
            exp = TimeInterval(value)
        } else if let value = json["exp"] as? Double {
            exp = value
        } else {
            exp = nil
        }
        guard let exp else { return true }
        return Date().timeIntervalSince1970 >= (exp - skewSeconds)
    }

    private static func jwtPayloadJSON(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - payload.count % 4
        if pad < 4 { payload += String(repeating: "=", count: pad) }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
