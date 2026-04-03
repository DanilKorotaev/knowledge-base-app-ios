import XCTest
@testable import KnowledgeBaseApp

final class URLMIMETypeTests: XCTestCase {
    func testPreferredMimeFromExtension() {
        let jpg = URL(fileURLWithPath: "/tmp/x.jpg")
        XCTAssertEqual(jpg.kbPreferredMIMEType, "image/jpeg")
        let pdf = URL(fileURLWithPath: "/tmp/y.PDF")
        XCTAssertEqual(pdf.kbPreferredMIMEType, "application/pdf")
    }
}
