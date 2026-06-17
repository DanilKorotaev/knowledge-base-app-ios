import XCTest
@testable import KnowledgeBaseApp

final class URLMIMETypeTests: XCTestCase {
    func testPreferredMimeFromExtension() {
        let jpg = URL(fileURLWithPath: "/tmp/x.jpg")
        XCTAssertEqual(jpg.kbPreferredMIMEType, "image/jpeg")
        let pdf = URL(fileURLWithPath: "/tmp/y.PDF")
        XCTAssertEqual(pdf.kbPreferredMIMEType, "application/pdf")
    }

    func testPreferredMimeCoversCommonAttachmentTypes() {
        let cases: [(String, String)] = [
            ("photo.jpeg", "image/jpeg"),
            ("icon.png", "image/png"),
            ("shot.heic", "image/heic"),
            ("anim.gif", "image/gif"),
            ("thumb.webp", "image/webp"),
            ("notes.txt", "text/plain"),
            ("readme.md", "text/markdown"),
            ("unknown.bin", "application/octet-stream"),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(URL(fileURLWithPath: "/tmp/\(name)").kbPreferredMIMEType, expected)
        }
    }
}
