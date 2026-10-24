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
    }

    @MainActor
    func apply(tokens: AuthTokenResponse) {
        KeychainTokenStore.setSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        AppConfiguration.setUserString(tokens.accessToken, for: AppConfiguration.Keys.authToken)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        currentUser = tokens.user
        isAuthenticated = true
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
        isAuthenticated = true
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
    }

    @MainActor
    func clear(logoutRemote: Bool = true) async {
        let access = accessToken
        let refresh = refreshToken
        if logoutRemote, let client = URLSessionAuthAPIClient.makeFromConfiguration() {
            try? await client.logout(accessToken: access, refreshToken: refresh)
        }
        KeychainTokenStore.clearSession()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.authToken)
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        NotificationCenter.default.post(name: .kbAuthSessionDidChange, object: nil)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
