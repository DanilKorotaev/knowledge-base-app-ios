import XCTest
@testable import KnowledgeBaseApp

final class AuthAPIClientTests: XCTestCase {
    func testDecodeTokenResponse() throws {
        let json = """
        {
          "access_token": "acc",
          "refresh_token": "ref",
          "token_type": "bearer",
          "expires_in": 3600,
          "user": {
            "id": 7,
            "login": "alice",
            "email": "a@example.com",
            "role": "user",
            "must_change_password": false,
            "cursor_isolation": "strict",
            "vault_root_relative": "users/alice",
            "nextcloud_username": "alice"
          }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AuthTokenResponse.self, from: json)
        XCTAssertEqual(decoded.accessToken, "acc")
        XCTAssertEqual(decoded.refreshToken, "ref")
        XCTAssertEqual(decoded.user.login, "alice")
        XCTAssertEqual(decoded.user.vaultRootRelative, "users/alice")
        XCTAssertFalse(decoded.user.mustChangePassword)
    }

    func testDecodeSignupStatus() throws {
        let json = #"{"open_signup":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AuthSignupStatus.self, from: json)
        XCTAssertTrue(decoded.openSignup)
    }

    func testKeychainSessionRoundTrip() {
        KeychainTokenStore.clearSession()
        let access = "access-\(UUID().uuidString)"
        let refresh = "refresh-\(UUID().uuidString)"
        KeychainTokenStore.setSession(accessToken: access, refreshToken: refresh)
        XCTAssertEqual(KeychainTokenStore.token(), access)
        XCTAssertEqual(KeychainTokenStore.refreshToken(), refresh)
        KeychainTokenStore.clearSession()
        XCTAssertNil(KeychainTokenStore.token())
        XCTAssertNil(KeychainTokenStore.refreshToken())
    }
}
