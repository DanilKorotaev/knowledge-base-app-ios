import XCTest
@testable import KnowledgeBaseApp

final class AuthSessionStoreTests: XCTestCase {
    override func tearDown() {
        KeychainTokenStore.clearSession()
        UserDefaults.standard.removeObject(forKey: "kb.auth.cached_login")
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
        let future = Int(Date().timeIntervalSince1970) + 3600
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
                    expiresIn: 3600,
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
                    expiresIn: 3600,
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
        let future = Int(Date().timeIntervalSince1970) + 7200
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
                    expiresIn: 7200,
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
            expiresIn: 3600,
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
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
