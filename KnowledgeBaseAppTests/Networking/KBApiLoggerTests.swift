import QuartzCore
import XCTest
@testable import KnowledgeBaseApp

final class KBApiLoggerTests: XCTestCase {
    private var settings: MockLoggerSettings!
    private var capture: CapturingLogger!
    private var base: KBApiLoggerBase!

    override func setUp() {
        super.setUp()
        settings = MockLoggerSettings()
        capture = CapturingLogger()
        base = KBApiLoggerBase(logger: capture, settings: settings)
    }

    func testLogMessageFromHeaders() {
        let text = base.logMessage(from: ["X-Test": "1", "Accept": "json"])
        XCTAssertTrue(text.contains("Headers:"))
        XCTAssertTrue(text.contains("X-Test"))
    }

    func testLogMessageFromEmptyHeadersReturnsEmpty() {
        XCTAssertEqual(base.logMessage(from: [:]), "")
        XCTAssertEqual(base.logMessage(from: nil), "")
    }

    func testLogMessageFromHTTPResponseWithJSONBody() throws {
        let url = URL(string: "https://kb.test/api")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = Data("{\"ok\":true}".utf8)
        let message = base.logMessage(from: response, data: body)
        XCTAssertTrue(message.contains("https://kb.test/api"))
        XCTAssertTrue(message.contains("Status: 200"))
        XCTAssertTrue(message.contains("HTTP Body:"))
        XCTAssertTrue(message.contains("\"ok\""))
    }

    func testLargeHTTPBodyIsTruncatedWhenEnabled() {
        settings.truncateLargeHTTPBodies = true
        settings.maxHTTPBodyLogBytes = 1_024
        let body = Data(repeating: 0x61, count: 2_048)
        let message = base.logMessage(from: body)
        XCTAssertTrue(message.contains("truncated"))
        XCTAssertTrue(message.contains("2048"))
    }

    func testLargeHTTPBodyIsKeptWhenTruncationDisabled() {
        settings.truncateLargeHTTPBodies = false
        let payload = String(repeating: "a", count: 5_000)
        let body = Data("{\"data\":\"\(payload)\"}".utf8)
        let message = base.logMessage(from: body)
        XCTAssertFalse(message.contains("truncated"))
        XCTAssertTrue(message.contains(payload.prefix(100)))
    }

    func testShortUrlIncludesPathAndQuery() {
        let url = URL(string: "https://kb.test/api/sessions?limit=10")!
        XCTAssertEqual(base.shortUrl(url), "/api/sessions?limit=10")
        XCTAssertEqual(base.shortUrl(nil), "")
    }

    func testKBApiLoggerVerboseRequestUsesCURL() throws {
        settings.isVerboseLog = true
        let apiLogger = KBApiLogger(logger: capture, settings: settings)
        var request = URLRequest(url: URL(string: "https://kb.test/x")!)
        request.httpMethod = "GET"
        apiLogger.log(request: request, id: "1")
        XCTAssertTrue(capture.entries.last?.message.contains("curl") == true)
    }

    func testKBApiLoggerNonVerboseRequestUsesShortUrl() throws {
        settings.isVerboseLog = false
        let apiLogger = KBApiLogger(logger: capture, settings: settings)
        let request = URLRequest(url: URL(string: "https://kb.test/items")!)
        apiLogger.log(request: request, id: "2")
        XCTAssertTrue(capture.entries.last?.message.contains("/items") == true)
    }

    func testKBApiLoggerSuccessAndErrorResponses() throws {
        let apiLogger = KBApiLogger(logger: capture, settings: settings)
        let url = URL(string: "https://kb.test/x")!
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let fail = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!

        apiLogger.log(response: ok, data: nil, id: "3", startTime: CACurrentMediaTime())
        XCTAssertEqual(capture.entries.last?.level, .info)

        apiLogger.log(response: fail, data: Data("err".utf8), id: "4", startTime: CACurrentMediaTime())
        XCTAssertEqual(capture.entries.last?.level, .error)
    }

    func testKBApiLoggerNetworkError() throws {
        let apiLogger = KBApiLogger(logger: capture, settings: settings)
        let url = URL(string: "https://kb.test/x")!
        let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
        apiLogger.log(error: URLError(.timedOut), id: "5", response: response)
        XCTAssertEqual(capture.entries.last?.level, .error)
        XCTAssertTrue(capture.entries.last?.message.contains("503") == true)
    }
}
