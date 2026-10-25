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
            String(localized: "auth.error_missing_api_url")
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 503, apiMessage: "down").errorDescription,
            "down"
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 500, apiMessage: nil).errorDescription,
            "\(String(localized: "network.request_failed")) (HTTP 500)"
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil).errorDescription,
            String(localized: "network.invalid_response")
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.decodingFailed.errorDescription,
            String(localized: "network.decoding_failed")
        )
        XCTAssertEqual(
            KnowledgeBaseAPIError.invalidResponse(
                statusCode: 401,
                apiMessage: "Access token истёк"
            ).errorDescription,
            String(localized: "auth.session_expired")
        )
    }

    func testFilesAPIErrorDescriptions() {
        XCTAssertEqual(
            FilesAPIError.invalidResponse(statusCode: 400, apiMessage: "nope").errorDescription,
            "nope"
        )
        XCTAssertEqual(
            FilesAPIError.decodingFailed.errorDescription,
            String(localized: "network.decoding_failed")
        )
        XCTAssertEqual(
            FilesAPIError.invalidResponse(statusCode: 403, apiMessage: "forbidden").errorDescription,
            String(localized: "auth.session_expired")
        )
    }

    func testBoardsAPIErrorDescriptions() {
        XCTAssertEqual(
            BoardsAPIError.notFound.errorDescription,
            String(localized: "boards.error.not_found")
        )
        XCTAssertEqual(
            BoardsAPIError.invalidResponse(statusCode: 500, apiMessage: nil).errorDescription,
            "\(String(localized: "boards.error.generic")) (HTTP 500)"
        )
    }
}
