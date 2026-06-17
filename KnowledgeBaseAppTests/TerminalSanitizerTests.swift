import XCTest
@testable import KnowledgeBaseApp

final class TerminalSanitizerTests: XCTestCase {
    func testStripEscapeSequences_removesAnsiShowCursor() {
        let input = "Done.\n\u{1B}[?25h"
        XCTAssertEqual(TerminalSanitizer.stripEscapeSequences(input), "Done.")
    }

    func testStripEscapeSequences_removesOrphanCsiTail() {
        XCTAssertEqual(TerminalSanitizer.stripEscapeSequences("Done.[?25h"), "Done.")
    }

    func testStripEscapeSequences_emptyString() {
        XCTAssertEqual(TerminalSanitizer.stripEscapeSequences(""), "")
    }

    func testStripEscapeSequences_removesColorCodes() {
        let input = "Hi \u{1B}[31mthere\u{1B}[0m"
        XCTAssertEqual(TerminalSanitizer.stripEscapeSequences(input), "Hi there")
    }
}
