import XCTest
@testable import KnowledgeBaseApp

final class KBLoggerTagsProviderTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var previousShared: UserDefaultsServiceDescription!

    override func setUp() {
        super.setUp()
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        suiteName = isolated.suiteName
        storage = isolated.storage
        previousShared = UserDefaultsService.shared
        UserDefaultsService.shared = UserDefaultsService(storage: storage)
    }

    override func tearDown() {
        KBLoggerTagsProvider.shared.resetToDefaults()
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testDisableAndEnableTag() {
        let provider = KBLoggerTagsProvider.shared
        provider.set(isEnabled: false, for: .voice)
        XCTAssertFalse(provider.isEnabled(tag: .voice))
        XCTAssertTrue(provider.excludedTags.contains(.voice))

        provider.set(isEnabled: true, for: .voice)
        XCTAssertTrue(provider.isEnabled(tag: .voice))
        XCTAssertFalse(provider.excludedTags.contains(.voice))
    }

    func testSetAllAndResetToDefaults() {
        let provider = KBLoggerTagsProvider.shared
        provider.setAll(isEnabled: false)
        XCTAssertFalse(provider.isEnabled(tag: .network))

        provider.resetToDefaults()
        XCTAssertTrue(provider.isEnabled(tag: .network))
        XCTAssertFalse(provider.isEnabled(tag: .chat))
    }

    func testChatTagDisabledByDefaultWhenUnset() {
        let key = UserDefaultsKeyPrefix.loggerTag.appending(LoggerTag.chat.rawValue) + ".enabled"
        storage.removeObject(forKey: key)
        XCTAssertFalse(KBLoggerTagsProvider.shared.isEnabled(tag: .chat))
    }

    func testTagsListIncludesUserDefaultsService() {
        XCTAssertTrue(KBLoggerTagsProvider.shared.tags.contains(.userDefaultsService))
    }
}
