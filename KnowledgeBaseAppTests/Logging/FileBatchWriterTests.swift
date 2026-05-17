import XCTest
@testable import KnowledgeBaseApp

final class FileBatchWriterTests: XCTestCase {
    func testWritesAndFlushesOnClose() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kb-log-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = FileBatchWriter(url: url, batchCapacity: 2)
        writer.write("line-1\n")
        writer.write("line-2\n")
        writer.close()

        let expectation = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("line-1"))
        XCTAssertTrue(text.contains("line-2"))
    }
}
