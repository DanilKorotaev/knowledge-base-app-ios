import XCTest
@testable import KnowledgeBaseApp

final class KBSessionTests: XCTestCase {
    func testDecodeArrayJSON() throws {
        let json = """
        [
          {"id":"s1","title":"Workout","message_count":12,"updated_at":"2026-03-29T10:00:00Z","use_knowledge_base":false}
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sessions = try decoder.decode([KBSession].self, from: json)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "s1")
        XCTAssertEqual(sessions[0].title, "Workout")
        XCTAssertEqual(sessions[0].messageCount, 12)
        XCTAssertFalse(sessions[0].useKnowledgeBase)
        XCTAssertNotNil(sessions[0].updatedAt)
    }

    func testDecodeDefaultsUseKnowledgeBaseToTrue() throws {
        let json = """
        [{"id":"s1","title":"Workout","message_count":0}]
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode([KBSession].self, from: json)[0]
        XCTAssertTrue(session.useKnowledgeBase)
    }

    func testDecodePagedItemsWrapper() throws {
        let json = """
        {"items":[{"id":"a","title":"A","message_count":0}]}
        """.data(using: .utf8)!

        struct Page: Codable {
            let items: [KBSession]?
        }

        let page = try JSONDecoder().decode(Page.self, from: json)
        XCTAssertEqual(page.items?.first?.id, "a")
    }
}
