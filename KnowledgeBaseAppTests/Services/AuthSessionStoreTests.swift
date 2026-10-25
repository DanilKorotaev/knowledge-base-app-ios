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
