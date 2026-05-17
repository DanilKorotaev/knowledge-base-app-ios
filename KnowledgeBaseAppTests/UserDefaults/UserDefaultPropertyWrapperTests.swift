import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultPropertyWrapperTests: XCTestCase {
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
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testUserDefaultReadsDefaultWhenMissing() {
        let key = "kb.wrapper.default.\(UUID().uuidString)"
        let subject = UserDefault<Int>(key: key, defaultValue: 7)
        XCTAssertEqual(subject.wrappedValue, 7)
    }

    func testUserDefaultWritesAndReads() {
        let key = "kb.wrapper.rw.\(UUID().uuidString)"
        var subject = UserDefault<String>(key: key, defaultValue: "default")
        subject.wrappedValue = "stored"
        XCTAssertEqual(subject.wrappedValue, "stored")
        XCTAssertEqual(storage.string(forKey: key), "stored")
    }

    func testInspectorSettingsShouldNotIgnoreOwnKeys() {
        let settings = UserDefaultsInspectorSettings.shared
        XCTAssertFalse(settings.shouldIgnoreAddOrUpdate(for: UserDefaultsKey.inspectorVerboseLogging.rawValue))
        XCTAssertFalse(settings.shouldIgnoreAddOrUpdate(for: UserDefaultsKey.inspectorIgnoredUpdateKeys.rawValue))
    }
}
