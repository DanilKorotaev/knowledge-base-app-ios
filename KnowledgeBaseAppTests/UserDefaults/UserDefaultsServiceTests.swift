import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsServiceTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var service: UserDefaultsService!
    private var previousShared: UserDefaultsServiceDescription!

    override func setUp() {
        super.setUp()
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        suiteName = isolated.suiteName
        storage = isolated.storage
        previousShared = UserDefaultsService.shared
        service = UserDefaultsService(storage: storage)
        UserDefaultsService.shared = service
    }

    override func tearDown() {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testSetAndGetString() {
        let key = "kb.test.string.\(UUID().uuidString)"
        service.set("value", forKey: key)
        XCTAssertEqual(service.string(forKey: key), "value")
    }

    func testIgnoredWriteDoesNotPersist() {
        let settings = MockUserDefaultsServiceSettings()
        settings.ignoredAddOrUpdateKeys = ["kb.test.ignored"]
        let guarded = UserDefaultsService(storage: storage, settings: settings)
        guarded.set("blocked", forKey: "kb.test.ignored")
        XCTAssertNil(storage.string(forKey: "kb.test.ignored"))
    }

    func testPostsNotificationOnWrite() {
        let expectation = expectation(description: "write notification")
        let key = "kb.test.notify.\(UUID().uuidString)"
        let observer = NotificationCenter.default.addObserver(
            forName: .userDefaultsServiceDidHandleOperation,
            object: nil,
            queue: nil
        ) { notification in
            guard
                let event = notification.userInfo?["event"] as? UserDefaultsServiceEvent,
                event.key == key,
                event.isWrite
            else {
                return
            }
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        service.set("ping", forKey: key)
        wait(for: [expectation], timeout: 1)
    }

    func testRemoveObject() {
        let key = "kb.test.remove.\(UUID().uuidString)"
        service.set("temp", forKey: key)
        service.removeObject(forKey: key)
        XCTAssertNil(service.object(forKey: key))
    }
}
