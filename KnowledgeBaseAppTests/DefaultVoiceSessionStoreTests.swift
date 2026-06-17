import XCTest
@testable import KnowledgeBaseApp

final class DefaultVoiceSessionStoreTests: XCTestCase {
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

    func testRoundTripSaveAndLoad() {
        let store = DefaultVoiceSessionStore()
        let preference = DefaultVoiceSessionPreference(
            sessionId: "125",
            sessionTitle: "Session 125",
            expiresAt: Date().addingTimeInterval(3600),
            previousSessionId: "100",
            previousSessionTitle: "Previous"
        )

        store.save(preference)
        let loaded = store.load()

        XCTAssertEqual(loaded, preference)
    }

    func testLoadReturnsNilWhenMissing() {
        let store = DefaultVoiceSessionStore()
        XCTAssertNil(store.load())
    }

    func testClearRemovesPreference() {
        let store = DefaultVoiceSessionStore()
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "1",
                sessionTitle: "One",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        store.clear()

        XCTAssertNil(store.load())
    }

    func testLoadReturnsNilForCorruptPayload() {
        storage.set(Data([0x00, 0x01, 0x02]), forKey: UserDefaultsKey.defaultVoiceSession.rawValue)
        let store = DefaultVoiceSessionStore()
        XCTAssertNil(store.load())
    }
}
