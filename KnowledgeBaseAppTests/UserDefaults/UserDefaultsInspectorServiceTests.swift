import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsInspectorServiceTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var service: UserDefaultsService!
    private var inspector: UserDefaultsInspectorService!
    private var previousShared: UserDefaultsServiceDescription!

    override func setUp() {
        super.setUp()
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        suiteName = isolated.suiteName
        storage = isolated.storage
        previousShared = UserDefaultsService.shared
        service = UserDefaultsService(storage: storage)
        UserDefaultsService.shared = service
        inspector = UserDefaultsInspectorService(userDefaultsService: service)
    }

    override func tearDown() {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testSaveStringAddsKey() throws {
        let key = "kb.inspector.save.\(UUID().uuidString)"
        let update = UserDefaultsInspectorUpdate(
            valueType: .string,
            stringValue: "hello",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )

        let item = try inspector.save(update: update, for: key)
        XCTAssertEqual(item.key, key)
        XCTAssertEqual(item.snapshot.valueType, .string)
        XCTAssertEqual(item.snapshot.stringValue, "hello")
    }

    func testDeleteRemovesKey() {
        let key = "kb.inspector.delete.\(UUID().uuidString)"
        service.set("bye", forKey: key)
        inspector.delete(key: key)
        XCTAssertNil(service.object(forKey: key))
    }

    func testIsSystemKeyApplePrefix() {
        XCTAssertTrue(inspector.isSystemKey("com.apple.configuration.migrated"))
        XCTAssertFalse(inspector.isSystemKey("kbapp.config.api_base_url"))
    }

    func testPostsChangeNotificationOnSave() throws {
        let expectation = expectation(description: "inspector change")
        let key = "kb.inspector.notify.\(UUID().uuidString)"
        let observer = NotificationCenter.default.addObserver(
            forName: .userDefaultsInspectorDidChange,
            object: nil,
            queue: nil
        ) { notification in
            guard
                notification.userInfo?[UserDefaultsInspectorNotificationKeys.key] as? String == key,
                notification.userInfo?[UserDefaultsInspectorNotificationKeys.action] as? String
                    == UserDefaultsInspectorChangeAction.added.rawValue
            else {
                return
            }
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let update = UserDefaultsInspectorUpdate(
            valueType: .bool,
            stringValue: "",
            boolValue: true,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        _ = try inspector.save(update: update, for: key)
        wait(for: [expectation], timeout: 1)
    }
}
