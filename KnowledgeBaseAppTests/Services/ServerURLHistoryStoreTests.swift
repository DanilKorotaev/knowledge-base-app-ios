@testable import KnowledgeBaseApp
import XCTest

final class ServerURLHistoryStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ServerURLHistoryStore.clear()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.apiBaseURL)
    }

    override func tearDown() {
        ServerURLHistoryStore.clear()
        AppConfiguration.setUserString(nil, for: AppConfiguration.Keys.apiBaseURL)
        super.tearDown()
    }

    func testRememberNormalizesAndDedupesCaseInsensitive() {
        ServerURLHistoryStore.remember("https://api.example.com/")
        ServerURLHistoryStore.remember("https://API.Example.com")
        ServerURLHistoryStore.remember("staging.example.com")

        let suggestions = ServerURLHistoryStore.suggestions()
        XCTAssertEqual(suggestions.first, "https://staging.example.com")
        XCTAssertEqual(suggestions.filter { $0.lowercased().contains("api.example.com") }.count, 1)
        XCTAssertEqual(ServerURLHistoryStore.preferredPrefill(), "https://staging.example.com")
    }

    func testPrefersConfiguredApiBaseURL() {
        ServerURLHistoryStore.remember("https://old.example.com")
        AppConfiguration.setUserString("https://current.example.com", for: AppConfiguration.Keys.apiBaseURL)

        XCTAssertEqual(ServerURLHistoryStore.preferredPrefill(), "https://current.example.com")
        XCTAssertEqual(ServerURLHistoryStore.suggestions().first, "https://current.example.com")
        XCTAssertTrue(ServerURLHistoryStore.suggestions().contains("https://old.example.com"))
    }

    func testHistoryCapped() {
        for index in 0 ..< (ServerURLHistoryStore.maxItems + 3) {
            ServerURLHistoryStore.remember("https://host\(index).example.com")
        }
        XCTAssertEqual(ServerURLHistoryStore.suggestions().count, ServerURLHistoryStore.maxItems)
        XCTAssertEqual(
            ServerURLHistoryStore.suggestions().first,
            "https://host\(ServerURLHistoryStore.maxItems + 2).example.com"
        )
    }
}
