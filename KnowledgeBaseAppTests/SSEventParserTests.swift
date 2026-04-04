import XCTest
@testable import KnowledgeBaseApp

final class SSEventParserTests: XCTestCase {
    func testSingleDataPayload() {
        let sse = "data: hello world\n\n"
        let payloads = SSEventParser.dataPayloads(fromCompleteBody: sse)
        XCTAssertEqual(payloads, ["hello world"])
    }

    func testMultiLineDataJoinedWithNewline() {
        let sse = "data: line one\ndata: line two\n\n"
        let payloads = SSEventParser.dataPayloads(fromCompleteBody: sse)
        XCTAssertEqual(payloads, ["line one\nline two"])
    }

    func testIgnoresCommentLines() {
        let sse = ": ping\ndata: ok\n\n"
        let payloads = SSEventParser.dataPayloads(fromCompleteBody: sse)
        XCTAssertEqual(payloads, ["ok"])
    }

    func testMultipleEvents() {
        let sse = "data: first\n\n: ignore\ndata: second\n\n"
        let payloads = SSEventParser.dataPayloads(fromCompleteBody: sse)
        XCTAssertEqual(payloads, ["first", "second"])
    }

    func testStreamBufferIncrementalChunks() {
        var buf = SSEventParser.StreamBuffer()
        XCTAssertEqual(buf.append("data: "), [])
        XCTAssertEqual(buf.append("chunk"), [])
        XCTAssertEqual(buf.append("\n\n"), ["chunk"])
    }

    func testStreamBufferSplitsAcrossChunkBoundary() {
        var buf = SSEventParser.StreamBuffer()
        XCTAssertEqual(buf.append("data: a\n"), [])
        XCTAssertEqual(buf.append("\ndata: b\n\n"), ["a", "b"])
    }
}
