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
            "nextcloud_username": "alice",
            "kb_folder": "/KnowledgeBase",
            "has_nc_app_password": true
          }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AuthTokenResponse.self, from: json)
        XCTAssertEqual(decoded.accessToken, "acc")
        XCTAssertEqual(decoded.refreshToken, "ref")
        XCTAssertEqual(decoded.user.login, "alice")
        XCTAssertEqual(decoded.user.vaultRootRelative, "users/alice")
        XCTAssertEqual(decoded.user.kbFolder, "/KnowledgeBase")
        XCTAssertEqual(decoded.user.hasNcAppPassword, true)
        XCTAssertFalse(decoded.user.mustChangePassword)
    }

    func testDecodeNcFoldersResponse() throws {
        let json = """
        {
          "current": "/kb",
          "browse_path": "/kb",
          "parent_path": "/",
          "has_nc_app_password": true,
          "folders": [
            {"path": "/kb/notes", "name": "notes"}
          ]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AuthNcFoldersResponse.self, from: json)
        XCTAssertEqual(decoded.current, "/kb")
        XCTAssertEqual(decoded.browsePath, "/kb")
        XCTAssertEqual(decoded.parentPath, "/")
        XCTAssertTrue(decoded.hasNcAppPassword)
        XCTAssertEqual(decoded.folders.count, 1)
        XCTAssertEqual(decoded.folders[0].path, "/kb/notes")
    }

    func testDecodeNcFoldersResponseDefaultsBrowsePath() throws {
        let json = """
        {
          "current": "/",
          "has_nc_app_password": false,
          "folders": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AuthNcFoldersResponse.self, from: json)
        XCTAssertEqual(decoded.browsePath, "/")
        XCTAssertNil(decoded.parentPath)
        XCTAssertFalse(decoded.hasNcAppPassword)
        XCTAssertEqual(decoded.folders.count, 0)
        let manual = AuthNcFoldersResponse(
            current: "/kb",
            browsePath: "/kb",
            parentPath: "/",
            hasNcAppPassword: true,
            folders: [AuthNcFolderDTO(path: "/kb/a", name: "a")]
        )
        XCTAssertEqual(manual.folders.first?.id, "/kb/a")
    }

    func testAuthAPIErrorDescriptions() {
        XCTAssertEqual(
            AuthAPIError.missingBaseURL.errorDescription,
            String(localized: "auth.error_missing_api_url")
        )
        XCTAssertEqual(
            AuthAPIError.invalidResponse(statusCode: 401, message: "Access token истёк").errorDescription,
            String(localized: "auth.session_expired")
        )
        XCTAssertEqual(
            AuthAPIError.invalidResponse(statusCode: 500, message: "boom").errorDescription,
            "boom"
        )
        XCTAssertEqual(
            AuthAPIError.decodingFailed.errorDescription,
            String(localized: "network.decoding_failed")
        )
    }

    func testDefinitiveAuthFailureOnlyFor401403() {
        XCTAssertTrue(AuthAPIError.invalidResponse(statusCode: 401, message: nil).isUnauthorized)
        XCTAssertTrue(AuthAPIError.invalidResponse(statusCode: 403, message: nil).isUnauthorized)
        XCTAssertFalse(AuthAPIError.invalidResponse(statusCode: 500, message: "boom").isUnauthorized)
        XCTAssertFalse(AuthAPIError.decodingFailed.isUnauthorized)
        XCTAssertTrue(
            AuthAPIError.isDefinitiveAuthFailure(
                AuthAPIError.invalidResponse(statusCode: 401, message: nil)
            )
        )
        XCTAssertFalse(
            AuthAPIError.isDefinitiveAuthFailure(
                URLError(.notConnectedToInternet)
            )
        )
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
