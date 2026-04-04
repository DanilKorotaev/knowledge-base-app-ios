import XCTest
@testable import KnowledgeBaseApp

final class KeychainTokenStoreTests: XCTestCase {
    override func tearDown() {
        KeychainTokenStore.setToken(nil)
        super.tearDown()
    }

    func testRoundTrip() {
        KeychainTokenStore.setToken("test-token-\(UUID().uuidString)")
        XCTAssertEqual(KeychainTokenStore.token()?.contains("test-token-"), true)
        KeychainTokenStore.setToken(nil)
        XCTAssertNil(KeychainTokenStore.token())
    }

    func testAppConfigurationSaveClearsUserDefaultsAndWritesKeychain() {
        KeychainTokenStore.setToken(nil)
        UserDefaults.standard.set("should-be-cleared", forKey: "kbapp.config.auth_token")

        let tok = "persist-\(UUID().uuidString)"
        AppConfiguration.setUserString(tok, for: AppConfiguration.Keys.authToken)

        XCTAssertEqual(KeychainTokenStore.token(), tok)
        XCTAssertNil(UserDefaults.standard.string(forKey: "kbapp.config.auth_token"))

        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.authToken)
        XCTAssertNil(KeychainTokenStore.token())
    }
}
