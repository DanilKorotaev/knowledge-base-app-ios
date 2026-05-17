import XCTest
@testable import KnowledgeBaseApp

final class LoggingUtilityTests: XCTestCase {
    func testCollectionGroup() {
        let grouped = ["ab", "aa", "b"].group(by: { String($0.prefix(1)) })
        XCTAssertEqual(grouped["a"]?.count, 2)
        XCTAssertEqual(grouped["b"]?.count, 1)
    }

    func testRegularExpressionMatches() throws {
        let regex = try NSRegularExpression(pattern: "\\[([^\\]]+)\\]")
        let matches = regex.matches(in: "[Network] hello [HTTP]")
        XCTAssertEqual(matches, ["[Network]", "[HTTP]"])
    }
}
