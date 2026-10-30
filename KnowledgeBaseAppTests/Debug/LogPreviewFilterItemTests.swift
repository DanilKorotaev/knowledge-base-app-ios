@testable import KnowledgeBaseApp
import XCTest

final class LogPreviewFilterItemTests: XCTestCase {
    func testTagTextAndValue() {
        let item = LogPreviewFilterItem.tag("[Network] ", count: 3)
        XCTAssertEqual(item.text, "[Network]  3")
        XCTAssertEqual(item.value, "[Network] ")
    }
}
