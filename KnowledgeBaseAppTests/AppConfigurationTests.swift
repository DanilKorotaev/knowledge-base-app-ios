import XCTest
@testable import KnowledgeBaseApp

final class AppConfigurationTests: XCTestCase {
    func testSetUserStringAndReadBack() {
        let key = "TEST_KEY_\(UUID().uuidString)"
        AppConfiguration.setUserString(" https://api.example.test ", for: key)

        XCTAssertEqual(AppConfiguration.string(for: key), "https://api.example.test")
    }

    func testSetUserStringNilRemovesValue() {
        let key = "TEST_KEY_REMOVE_\(UUID().uuidString)"
        AppConfiguration.setUserString("value", for: key)
        AppConfiguration.setUserString(nil, for: key)

        XCTAssertNil(AppConfiguration.string(for: key))
    }

    func testURLForKey_returnsNilWhenUnset() {
        XCTAssertNil(AppConfiguration.url(for: "UNKNOWN_KEY_\(UUID().uuidString)"))
    }

    /// Runtime URL from onboarding/Settings must win over any baked Info.plist default
    /// (TestFlight CI still injects `KBAPP_API_BASE_URL` into the bundle).
    func testApiBaseURL_userDefaultsWinsOverBundleFallback() {
        let previous = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL)
        defer {
            AppConfiguration.setUserString(previous, for: AppConfiguration.Keys.apiBaseURL)
        }

        let staging = "https://kbapp.staging.example.test"
        AppConfiguration.setUserString(staging, for: AppConfiguration.Keys.apiBaseURL)

        XCTAssertEqual(AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL), staging)
        XCTAssertEqual(AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL)?.absoluteString, staging)
    }

    func testAuthToken_keychainWinsOverBundleFallback() {
        let previous = KeychainTokenStore.token()
        defer {
            KeychainTokenStore.setToken(previous)
        }

        let sessionToken = "runtime-session-token-\(UUID().uuidString)"
        AppConfiguration.setUserString(sessionToken, for: AppConfiguration.Keys.authToken)

        XCTAssertEqual(AppConfiguration.string(for: AppConfiguration.Keys.authToken), sessionToken)
    }
}
