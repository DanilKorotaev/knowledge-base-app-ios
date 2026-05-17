import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsKeyRegistryTests: XCTestCase {
    func testKnownKeyExactMatch() {
        let known = UserDefaultsKeyRegistry.knownKey(for: UserDefaultsKey.apiBaseURL.rawValue)
        XCTAssertEqual(known?.key, .apiBaseURL)
        XCTAssertEqual(known?.category, .config)
        XCTAssertEqual(known?.valueType, .string)
    }

    func testKnownKeyPrefixMatchLoggerTag() {
        let dynamicKey = UserDefaultsKeyPrefix.loggerTag.appending("Network")
        let known = UserDefaultsKeyRegistry.knownKey(for: dynamicKey)
        XCTAssertEqual(known?.category, .loggerTags)
        XCTAssertEqual(known?.valueType, .bool)
        XCTAssertTrue(known?.description.contains("tag") == true || known?.description.isEmpty == false)
    }

    func testUnknownKeyReturnsNil() {
        XCTAssertNil(UserDefaultsKeyRegistry.knownKey(for: "kb.unknown.\(UUID().uuidString)"))
    }
}
