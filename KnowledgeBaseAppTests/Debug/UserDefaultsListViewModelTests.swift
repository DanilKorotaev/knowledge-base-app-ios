import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsListViewModelTests: XCTestCase {
    private var suiteName: String!
    private var storage: UserDefaults!
    private var service: UserDefaultsInspectorService!
    private var viewModel: UserDefaultsListView.ViewModel!
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
        viewModel = UserDefaultsListView.ViewModel(service: service)
    }

    override func tearDown() {
        UserDefaultsService.shared = previousShared
        UserDefaultsTestSupport.tearDown(storage: storage, suiteName: suiteName)
        super.tearDown()
    }

    func testReloadFiltersSearchAndSort() throws {
        let key = "kb.list.vm.\(UUID().uuidString)"
        try service.save(
            update: UserDefaultsInspectorUpdate(
                valueType: .string,
                stringValue: "alpha",
                boolValue: false,
                dateValue: Date(),
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            ),
            for: key
        )
        UserDefaultsService.shared.set(true, forKey: UserDefaultsKey.apiBaseURL)

        viewModel.didLoadView()
        XCTAssertFalse(viewModel.sections.isEmpty)

        viewModel.searchText = key.lowercased()
        XCTAssertEqual(viewModel.sections.flatMap(\.items).count, 1)

        viewModel.searchText = ""
        viewModel.filterType = .unknown
        XCTAssertTrue(viewModel.sections.flatMap(\.items).contains { $0.key == key })

        viewModel.filterType = .known
        XCTAssertTrue(viewModel.sections.flatMap(\.items).contains { $0.knownKey != nil })

        viewModel.sortType = .key
        XCTAssertEqual(viewModel.sections.count, 1)

        viewModel.sortType = .category
        XCTAssertFalse(viewModel.sections.isEmpty)
    }

    func testHideSystemKeysAndDelete() throws {
        storage.set("system", forKey: "com.apple.test.key")
        let userKey = "kb.user.\(UUID().uuidString)"
        storage.set("value", forKey: userKey)

        viewModel.didLoadView()
        viewModel.showSystemKeys = false
        XCTAssertFalse(viewModel.sections.flatMap(\.items).contains { $0.key.hasPrefix("com.apple") })

        viewModel.showSystemKeys = true
        XCTAssertTrue(viewModel.sections.flatMap(\.items).contains { $0.key.hasPrefix("com.apple") })

        if let section = viewModel.sections.first(where: { $0.items.contains { $0.key == userKey } }) {
            let index = section.items.firstIndex { $0.key == userKey }!
            viewModel.deleteItems(in: section, at: IndexSet(integer: index))
        }
        XCTAssertNil(storage.object(forKey: userKey))
    }

    func testFilterTypeNames() {
        XCTAssertEqual(UserDefaultsListView.FilterType.all.name, "All")
        XCTAssertEqual(UserDefaultsListView.SortType.category.name, "By Category")
    }
}
