import XCTest
@testable import KnowledgeBaseApp

final class ServerProbeTests: XCTestCase {
    func testNormalizeAddsHTTPSAndStripsSlash() {
        XCTAssertEqual(
            ServerProbe.normalizeBaseURL("api.example.com/")?.absoluteString,
            "https://api.example.com"
        )
    }

    func testNormalizeRejectsEmpty() {
        XCTAssertNil(ServerProbe.normalizeBaseURL("   "))
    }

    func testNormalizeKeepsHTTP() {
        XCTAssertEqual(
            ServerProbe.normalizeBaseURL("http://localhost:8191")?.absoluteString,
            "http://localhost:8191"
        )
    }
}
