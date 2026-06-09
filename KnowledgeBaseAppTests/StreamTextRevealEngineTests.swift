import XCTest
@testable import KnowledgeBaseApp

final class StreamTextRevealEngineTests: XCTestCase {
    func testRevealsAtLeastOneCharacter() {
        let target = "Hello world"
        let end = StreamTextRevealEngine.nextRevealEndIndex(in: target, revealedCount: 0)
        XCTAssertGreaterThan(end, 0)
        XCTAssertLessThanOrEqual(end, target.count)
    }

    func testPrefersWordBoundary() {
        let target = "Hello world"
        let end = StreamTextRevealEngine.nextRevealEndIndex(in: target, revealedCount: 0, maxStep: 10)
        XCTAssertEqual(end, 6)
        XCTAssertEqual(String(target.prefix(end)), "Hello ")
    }

    func testStopsAtNewline() {
        let target = "Alpha\nBeta"
        let end = StreamTextRevealEngine.nextRevealEndIndex(in: target, revealedCount: 0, maxStep: 20)
        XCTAssertEqual(String(target.prefix(end)), "Alpha\n")
    }

    func testNumberedListRevealsBySentenceChunks() {
        let target = "1. First item.\n2. Second item."
        var revealed = 0
        var steps: [String] = []
        while revealed < target.count {
            let next = StreamTextRevealEngine.nextRevealEndIndex(in: target, revealedCount: revealed)
            XCTAssertGreaterThan(next, revealed)
            revealed = next
            steps.append(String(target.prefix(revealed)))
        }
        XCTAssertEqual(steps.last, target)
        XCTAssertGreaterThan(steps.count, 2)
    }

    func testReturnsRevealedCountWhenComplete() {
        let target = "Done"
        XCTAssertEqual(StreamTextRevealEngine.nextRevealEndIndex(in: target, revealedCount: 4), 4)
    }
}
