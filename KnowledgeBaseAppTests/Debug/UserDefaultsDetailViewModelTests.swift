import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsDetailViewModelTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var service: UserDefaultsInspectorService!
    private var previousShared: UserDefaultsServiceDescription!

    override func setUp() {
        super.setUp()
        let isolated = UserDefaultsTestSupport.makeIsolatedStorage()
        suiteName = isolated.suiteName
        storage = isolated.storage
        previousShared = UserDefaultsService.shared
        let udService = UserDefaultsService(storage: storage)
        UserDefaultsService.shared = udService
        service = UserDefaultsInspectorService(userDefaultsService: udService)
    }

    override func tearDown() {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testLoadAndUpdateStringValue() throws {
        let key = "kb.detail.\(UUID().uuidString)"
        _ = try service.save(
            update: UserDefaultsInspectorUpdate(
                valueType: .string,
                stringValue: "before",
                boolValue: false,
                dateValue: Date(),
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            ),
            for: key
        )

        let viewModel = UserDefaultsDetailView.ViewModel(key: key, service: service)
        XCTAssertEqual(viewModel.valueType, .string)
        XCTAssertEqual(viewModel.stringValue, "before")
        XCTAssertTrue(viewModel.canEditValue)

        viewModel.stringValue = "after"
        viewModel.didUpdateActionRequested()
        XCTAssertTrue(viewModel.success)
        XCTAssertEqual(storage.string(forKey: key), "after")
    }

    func testBoolValueIsNotEditable() throws {
        let key = "kb.detail.bool.\(UUID().uuidString)"
        _ = try service.save(
            update: UserDefaultsInspectorUpdate(
                valueType: .bool,
                stringValue: "",
                boolValue: true,
                dateValue: Date(),
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            ),
            for: key
        )

        let viewModel = UserDefaultsDetailView.ViewModel(key: key, service: service)
        XCTAssertEqual(viewModel.valuePreviewText, "true")
        XCTAssertFalse(viewModel.canEditValue)
    }

    func testDeleteAndReloadMissingKey() throws {
        let key = "kb.detail.delete.\(UUID().uuidString)"
        storage.set("x", forKey: key)
        let viewModel = UserDefaultsDetailView.ViewModel(key: key, service: service)
        viewModel.didDeleteActionRequested()
        viewModel.reload()
        XCTAssertEqual(viewModel.valueType, .unknown)
        XCTAssertEqual(viewModel.typeName, "nil")
    }
}
