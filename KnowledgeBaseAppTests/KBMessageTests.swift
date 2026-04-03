import XCTest
@testable import KnowledgeBaseApp

final class KBMessageTests: XCTestCase {
    func testDecodeMessageJSON() throws {
        let json = """
        {"id":"m1","role":"user","content":"Hello","created_at":"2026-04-04T12:00:00Z"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(KBMessage.self, from: json)

        XCTAssertEqual(message.id, "m1")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNotNil(message.createdAt)
    }
}
