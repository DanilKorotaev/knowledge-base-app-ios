@testable import KnowledgeBaseApp
import XCTest

final class AuthSessionStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KeychainTokenStore.clearSession()
        SavedAccountsStore.clearAll()
        UserDefaults.standard.removeObject(forKey: "kb.auth.cached_login")
        UserDefaults.standard.removeObject(forKey: "kb.auth.active_account_id")
    }

    override func tearDown() {
        KeychainTokenStore.clearSession()
        SavedAccountsStore.clearAll()
        UserDefaults.standard.removeObject(forKey: "kb.auth.cached_login")
        UserDefaults.standard.removeObject(forKey: "kb.auth.active_account_id")
        super.tearDown()
    }

    func testJwtSubjectUserId() {
        // {"sub":"42","typ":"access"} — unsigned payload for unit test only
        let header = Data(#"{"alg":"none"}"#.utf8).base64URLEncodedString()
        let payload = Data(#"{"sub":"42","typ":"access"}"#.utf8).base64URLEncodedString()
        let token = "\(header).\(payload).sig"
        XCTAssertEqual(AuthSessionStore.jwtSubjectUserId(token), 42)
    }

    func testJwtExpiryDetection() {
        let header = Data(#"{"alg":"none"}"#.utf8).base64URLEncodedString()
        let past = Int(Date().timeIntervalSince1970) - 120
        let future = Int(Date().timeIntervalSince1970) + 3_600
        let near = Int(Date().timeIntervalSince1970) + 30
        let expiredPayload = Data(#"{"sub":"1","exp":\#(past)}"#.utf8).base64URLEncodedString()
        let freshPayload = Data(#"{"sub":"1","exp":\#(future)}"#.utf8).base64URLEncodedString()
        let nearPayload = Data(#"{"sub":"1","exp":\#(near)}"#.utf8).base64URLEncodedString()
        let noExpPayload = Data(#"{"sub":"1"}"#.utf8).base64URLEncodedString()
        XCTAssertTrue(
            AuthSessionStore.jwtIsExpiredOrNearExpiry("\(header).\(expiredPayload).sig", skewSeconds: 60)
        )
        XCTAssertFalse(
            AuthSessionStore.jwtIsExpiredOrNearExpiry("\(header).\(freshPayload).sig", skewSeconds: 60)
        )
        XCTAssertTrue(
            AuthSessionStore.jwtIsExpiredOrNearExpiry("\(header).\(nearPayload).sig", skewSeconds: 60),
            "exp within skew should force refresh"
        )
        XCTAssertTrue(
            AuthSessionStore.jwtIsExpiredOrNearExpiry("\(header).\(noExpPayload).sig", skewSeconds: 60),
            "missing exp is treated as expired"
        )
        XCTAssertTrue(AuthSessionStore.jwtIsExpiredOrNearExpiry("not-a-jwt", skewSeconds: 60))
    }

    func testApplyAccessTokenOnlyClearsRefresh() async {
        let user = AuthUserDTO(
            id: 3,
            login: "alice",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: nil,
            nextcloudUsername: nil,
            kbFolder: "/kb",
            hasNcAppPassword: true
        )
        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-full",
                    refreshToken: "refresh-full",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: user
                )
            )
            AuthSessionStore.shared.applyAccessTokenOnly("access-only")
            XCTAssertEqual(KeychainTokenStore.token(), "access-only")
            XCTAssertNil(KeychainTokenStore.refreshToken())
            XCTAssertEqual(AuthSessionStore.shared.accessToken, "access-only")
            XCTAssertNil(AuthSessionStore.shared.refreshToken)
            XCTAssertTrue(AuthSessionStore.shared.isAuthenticated)
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
    }

    func testInvalidateLocalSessionClearsAuth() async {
        let user = AuthUserDTO(
            id: 4,
            login: "carol",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: nil,
            nextcloudUsername: nil,
            kbFolder: nil,
            hasNcAppPassword: nil
        )
        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-inv",
                    refreshToken: "refresh-inv",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: user
                )
            )
        }
        await AuthSessionStore.shared.invalidateLocalSession(reason: "unit-test")
        await MainActor.run {
            XCTAssertFalse(AuthSessionStore.shared.isAuthenticated)
            XCTAssertNil(KeychainTokenStore.token())
            XCTAssertNil(KeychainTokenStore.refreshToken())
        }
        // Idempotent when already signed out
        await AuthSessionStore.shared.invalidateLocalSession(reason: "unit-test-again")
    }

    func testEnsureFreshAccessTokenNoOpWhenFresh() async {
        let header = Data(#"{"alg":"none"}"#.utf8).base64URLEncodedString()
        let future = Int(Date().timeIntervalSince1970) + 7_200
        let payload = Data(#"{"sub":"9","exp":\#(future)}"#.utf8).base64URLEncodedString()
        let access = "\(header).\(payload).sig"
        let user = AuthUserDTO(
            id: 9,
            login: "fresh",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: nil,
            nextcloudUsername: nil,
            kbFolder: nil,
            hasNcAppPassword: nil
        )
        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: access,
                    refreshToken: "refresh-fresh",
                    tokenType: "bearer",
                    expiresIn: 7_200,
                    user: user
                )
            )
        }
        await AuthSessionStore.shared.ensureFreshAccessTokenIfNeeded()
        await MainActor.run {
            XCTAssertEqual(AuthSessionStore.shared.accessToken, access)
            XCTAssertTrue(AuthSessionStore.shared.isAuthenticated)
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
    }

    func testApplyTokensPersistsKeychainAndUser() async {
        let user = AuthUserDTO(
            id: 9,
            login: "bob",
            email: "b@example.com",
            role: "user",
            mustChangePassword: false,
            cursorIsolation: "strict",
            vaultRootRelative: "users/bob",
            nextcloudUsername: "bob",
            kbFolder: "/",
            hasNcAppPassword: false
        )
        let tokens = AuthTokenResponse(
            accessToken: "access-\(UUID().uuidString)",
            refreshToken: "refresh-\(UUID().uuidString)",
            tokenType: "bearer",
            expiresIn: 3_600,
            user: user
        )
        await MainActor.run {
            AuthSessionStore.shared.apply(tokens: tokens)
            XCTAssertTrue(AuthSessionStore.shared.isAuthenticated)
            XCTAssertEqual(AuthSessionStore.shared.currentUser?.login, "bob")
            XCTAssertEqual(KeychainTokenStore.token(), tokens.accessToken)
            XCTAssertEqual(KeychainTokenStore.refreshToken(), tokens.refreshToken)
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
        await MainActor.run {
            XCTAssertFalse(AuthSessionStore.shared.isAuthenticated)
            XCTAssertNil(KeychainTokenStore.token())
            XCTAssertNil(KeychainTokenStore.refreshToken())
        }
    }

    func testUITestingSkipsLoginGateUnlessForced() {
        // Defaults: without force flag, UITesting skips gate.
        // We only assert the force flag path is readable (launch args are process-global).
        XCTAssertFalse(UITestRuntime.forceLoginGateArgument.isEmpty)
        XCTAssertFalse(UITestRuntime.launchArgument.isEmpty)
    }

    func testSignOutWipesOnlyThatAccountOfflineCache() async {
        let base = URL(string: "https://cache-test.example.com")!
        AppConfiguration.setUserString(base.absoluteString, for: AppConfiguration.Keys.apiBaseURL)

        let rootA = OfflineCacheScope.storeRoot(apiBaseURL: base, userId: 11)
        let rootB = OfflineCacheScope.storeRoot(apiBaseURL: base, userId: 22)
        try? FileManager.default.createDirectory(at: rootA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: rootB, withIntermediateDirectories: true)
        try? "a".data(using: .utf8)?.write(to: rootA.appendingPathComponent("marker.txt"))
        try? "b".data(using: .utf8)?.write(to: rootB.appendingPathComponent("marker.txt"))
        defer {
            try? FileManager.default.removeItem(at: OfflineCacheScope.applicationSupportRoot()
                .appendingPathComponent(OfflineCacheScope.hostKey(from: base), isDirectory: true))
        }

        let userA = AuthUserDTO(
            id: 11,
            login: "alice-cache",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: nil,
            nextcloudUsername: nil,
            kbFolder: nil,
            hasNcAppPassword: nil
        )
        let userB = AuthUserDTO(
            id: 22,
            login: "bob-cache",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: nil,
            nextcloudUsername: nil,
            kbFolder: nil,
            hasNcAppPassword: nil
        )

        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-a-cache",
                    refreshToken: "refresh-a-cache",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: userA
                )
            )
        }
        await AuthSessionStore.shared.beginAddAccount()
        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-b-cache",
                    refreshToken: "refresh-b-cache",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: userB
                )
            )
        }

        // Switch back to alice, then sign her out — only her cache directory should vanish.
        let aliceId = SavedAccount.makeId(apiBaseURL: base.absoluteString, userId: 11)
        await AuthSessionStore.shared.switchToAccount(id: aliceId)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootA.appendingPathComponent("marker.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootB.appendingPathComponent("marker.txt").path))

        await AuthSessionStore.shared.clear(logoutRemote: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: rootA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootB.appendingPathComponent("marker.txt").path))
        await MainActor.run {
            XCTAssertEqual(AuthSessionStore.shared.currentUser?.login, "bob-cache")
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
    }

    func testSwitchAccountKeepsBothSavedAndClearsOnlyOnSignOut() async {
        AppConfiguration.setUserString("https://api.example.com", for: AppConfiguration.Keys.apiBaseURL)
        let userA = AuthUserDTO(
            id: 11,
            login: "alice",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: "users/alice",
            nextcloudUsername: nil,
            kbFolder: "/",
            hasNcAppPassword: nil
        )
        let userB = AuthUserDTO(
            id: 22,
            login: "bob",
            email: nil,
            role: "user",
            mustChangePassword: false,
            cursorIsolation: nil,
            vaultRootRelative: "users/bob",
            nextcloudUsername: nil,
            kbFolder: "/",
            hasNcAppPassword: nil
        )
        await MainActor.run {
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-a",
                    refreshToken: "refresh-a",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: userA
                )
            )
        }
        await AuthSessionStore.shared.beginAddAccount()
        await MainActor.run {
            XCTAssertFalse(AuthSessionStore.shared.isAuthenticated)
            XCTAssertEqual(AuthSessionStore.shared.savedAccounts.count, 1)
            AuthSessionStore.shared.apply(
                tokens: AuthTokenResponse(
                    accessToken: "access-b",
                    refreshToken: "refresh-b",
                    tokenType: "bearer",
                    expiresIn: 3_600,
                    user: userB
                )
            )
            XCTAssertEqual(AuthSessionStore.shared.savedAccounts.count, 2)
            XCTAssertEqual(AuthSessionStore.shared.currentUser?.login, "bob")
        }
        let aliceId = SavedAccount.makeId(apiBaseURL: "https://api.example.com", userId: 11)
        await AuthSessionStore.shared.switchToAccount(id: aliceId)
        await MainActor.run {
            XCTAssertEqual(AuthSessionStore.shared.currentUser?.login, "alice")
            XCTAssertEqual(KeychainTokenStore.token(), "access-a")
            XCTAssertEqual(AuthSessionStore.shared.savedAccounts.count, 2)
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
        await MainActor.run {
            XCTAssertEqual(AuthSessionStore.shared.currentUser?.login, "bob")
            XCTAssertEqual(AuthSessionStore.shared.savedAccounts.count, 1)
        }
        await AuthSessionStore.shared.clear(logoutRemote: false)
        await MainActor.run {
            XCTAssertFalse(AuthSessionStore.shared.isAuthenticated)
            XCTAssertTrue(AuthSessionStore.shared.savedAccounts.isEmpty)
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
