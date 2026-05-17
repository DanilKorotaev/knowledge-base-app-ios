import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsAddViewModelTests: XCTestCase {
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

    func testManualSave() throws {
        let key = "kb.add.manual.\(UUID().uuidString)"
        let viewModel = UserDefaultsAddView.ViewModel(service: service)
        viewModel.keyInputMode = .manual
        viewModel.manualKey = key
        viewModel.stringValue = "created"
        viewModel.didSaveActionRequested()

        XCTAssertTrue(viewModel.success)
        XCTAssertEqual(storage.string(forKey: key), "created")
    }

    func testRegistrySaveSetsValueTypeFromSelection() throws {
        let viewModel = UserDefaultsAddView.ViewModel(service: service)
        viewModel.selectedRegistryKey = UserDefaultsKeyRegistry.allKeys.first { $0.valueType == .bool }
        XCTAssertEqual(viewModel.valueType, .bool)
        viewModel.boolValue = true
        viewModel.didSaveActionRequested()
        XCTAssertTrue(viewModel.success)
        XCTAssertNotNil(viewModel.effectiveKey)
    }

    func testCanSaveRequiresKey() {
        let viewModel = UserDefaultsAddView.ViewModel(service: service)
        XCTAssertFalse(viewModel.canSave)
        viewModel.manualKey = "kb.add.key"
        viewModel.keyInputMode = .manual
        XCTAssertTrue(viewModel.canSave)
    }

    func testHandleExternalChangeUpdatesValueType() throws {
        let key = "kb.add.external.\(UUID().uuidString)"
        let viewModel = UserDefaultsAddView.ViewModel(service: service)
        viewModel.keyInputMode = .manual
        viewModel.manualKey = key
        _ = try service.save(
            update: UserDefaultsInspectorUpdate(
                valueType: .integer,
                stringValue: "7",
                boolValue: false,
                dateValue: Date(),
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            ),
            for: key
        )
        viewModel.handleExternalChange(changedKey: key)
        XCTAssertEqual(viewModel.valueType, .integer)
    }
}
