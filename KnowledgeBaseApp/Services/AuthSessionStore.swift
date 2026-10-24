import Foundation
import Observation

/// Owns login session: Keychain tokens + optional cached user profile.
@Observable
final class AuthSessionStore {
    static let shared = AuthSessionStore()

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var currentUser: AuthUserDTO?
    private(set) var isAuthenticated: Bool = false

    /// Serializes concurrent 401→refresh attempts.
    private let refreshLock = NSLock()
    private var refreshTask: Task<String, Error>?

    private init() {
        restoreFromKeychain()
    }

    var mustChangePassword: Bool {
        currentUser?.mustChangePassword == true
    }

    /// UI tests use stub clients and should skip the login gate (unless forced).
    var shouldPresentLoginGate: Bool {
        if UITestRuntime.forceLoginGate { return true }
        if UITestRuntime.isUITesting { return false }
        return !isAuthenticated
    }

    func restoreFromKeychain() {
        let access = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refresh = KeychainTokenStore.refreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        accessToken = access?.nilIfEmpty
        refreshToken = refresh?.nilIfEmpty
        isAuthenticated = accessToken != nil
        if currentUser == nil, let access, let sub = Self.jwtSubjectUserId(access) {
            // Minimal stub so offline cache scopes before /me returns.
            currentUser = AuthUserDTO(
                id: sub,
                login: UserDefaults.standard.string(forKey: Self.cachedLoginKey) ?? "user",
                email: nil,
                role: nil,
                mustChangePassword: false,
                cursorIsolation: nil,
                vaultRootRelative: nil,
                nextcloudUsername: nil
            )
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
                nextcloudUsername: nil
            )
        }
        isAuthenticated = true
        rebindCaches()
        PushNotificationService.shared.onAuthenticated()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    @MainActor
    func clear(logoutRemote: Bool = true) async {
        let access = accessToken
        let refresh = refreshToken
        await PushNotificationService.shared.unregisterFromServer()
        if logoutRemote, let client = URLSessionAuthAPIClient.makeFromConfiguration() {
            try? await client.logout(accessToken: access, refreshToken: refresh)
        }
        KeychainTokenStore.clearSession()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.authToken)
        UserDefaults.standard.removeObject(forKey: Self.cachedLoginKey)
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        rebindCaches()
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    private func rebindCaches() {
        let userId = currentUser?.id
        FileOfflineCacheStore.shared.rebindToCurrentUser(userId: userId)
        FileAttachmentDiskCache.shared.rebindToCurrentUser(userId: userId)
    }

    @MainActor
    func refreshProfile() async {
        guard let access = accessToken, let client = URLSessionAuthAPIClient.makeFromConfiguration() else { return }
        do {
            currentUser = try await client.me(accessToken: access)
        } catch {
            // Keep cached user if /me fails (offline).
        }
    }

    /// Returns a valid access token, refreshing once when needed.
    func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let access = accessToken, !access.isEmpty {
            return access
        }
        return try await refreshAccessToken()
    }

    func refreshAccessToken() async throws -> String {
        refreshLock.lock()
        if let existing = refreshTask {
            refreshLock.unlock()
            return try await existing.value
        }
        let task = Task<String, Error> {
            guard let refresh = KeychainTokenStore.refreshToken()?.nilIfEmpty else {
                throw AuthAPIError.invalidResponse(statusCode: 401, message: "Session expired")
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
        if let sub = json["sub"] as? String { return Int(sub) }
        if let sub = json["sub"] as? Int { return sub }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
