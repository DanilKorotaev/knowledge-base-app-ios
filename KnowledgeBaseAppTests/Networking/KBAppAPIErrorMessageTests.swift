import XCTest
@testable import KnowledgeBaseApp

final class KBAppAPIErrorMessageTests: XCTestCase {
    func testParseEnvelopePrefersMessage() {
        let data = """
        {"error":{"code":"NOT_FOUND","message":"Session missing","detail":"id=1"}}
        """.data(using: .utf8)!
        XCTAssertEqual(KBAppAPIErrorMessage.parse(from: data), "Session missing")
    }

    func testParseEnvelopeFallsBackToDetail() {
        let data = """
        {"error":{"detail":"bad input"}}
        """.data(using: .utf8)!
        XCTAssertEqual(KBAppAPIErrorMessage.parse(from: data), "bad input")
    }

    func testParseRawBodyWhenNotJSON() {
        let data = Data("plain text error".utf8)
        XCTAssertEqual(KBAppAPIErrorMessage.parse(from: data), "plain text error")
    }

    func testParseReturnsNilForEmptyData() {
        XCTAssertNil(KBAppAPIErrorMessage.parse(from: Data()))
    }

    func testKnowledgeBaseAPIErrorDescriptions() {
        XCTAssertEqual(
            KnowledgeBaseAPIError.missingBaseURL.errorDescription,
            "API base URL is not configured."
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 503, apiMessage: "down").errorDescription,
            "down"
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 500, apiMessage: nil).errorDescription,
            "Request failed (HTTP 500)."
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil).errorDescription,
            "Invalid server response."
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.decodingFailed.errorDescription,
            "Could not read server response."
        )
    }

    func testFilesAPIErrorDescriptions() {
        XCTAssertEqual(
            FilesAPIError.invalidResponse(statusCode: 400, apiMessage: "nope").errorDescription,
            "nope"
        )
        XCTAssertEqual(
            FilesAPIError.decodingFailed.errorDescription,
            "Could not read server response."
        )
    }
}
