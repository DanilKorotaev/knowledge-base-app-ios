import XCTest
@testable import KnowledgeBaseApp

final class URLRequestKBcURLTests: XCTestCase {
    func testKbCURLIncludesMethodURLAndHeaders() throws {
        var request = URLRequest(url: URL(string: "https://kb.test/api/sessions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer tok", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{\"title\":\"A\"}".utf8)

        let curl = request.kbCURL
        XCTAssertTrue(curl.contains("curl"))
        XCTAssertTrue(curl.contains("-X POST"))
        XCTAssertTrue(curl.contains("https://kb.test/api/sessions"))
        XCTAssertTrue(curl.contains("Authorization"))
        XCTAssertTrue(curl.contains("--data"))
    }

    func testKbCURLEscapesSingleQuotesInBody() throws {
        var request = URLRequest(url: URL(string: "https://kb.test/x")!)
        request.httpMethod = "POST"
        request.httpBody = Data("it's fine".utf8)

        XCTAssertTrue(request.kbCURL.contains("it'\\''s fine"))
    }

    func testKbCURLBinaryBodyPlaceholder() throws {
        var request = URLRequest(url: URL(string: "https://kb.test/x")!)
        request.httpBody = Data([0xFF, 0xFE, 0xFD])

        XCTAssertTrue(request.kbCURL.contains("bytes binary"))
    }
}
