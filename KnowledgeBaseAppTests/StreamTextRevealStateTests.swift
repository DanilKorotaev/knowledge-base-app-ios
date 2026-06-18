import XCTest
@testable import KnowledgeBaseApp

@MainActor
final class StreamTextRevealStateTests: XCTestCase {
    func testRevealContinuesWhenTargetGrowsWithoutRestarting() async {
        let state = StreamTextRevealState()
        var growthCount = 0
        state.onGrowth = { growthCount += 1 }

        state.updateTarget("Hello ", finishing: false)
        try? await Task.sleep(for: .milliseconds(80))
        let afterFirstWord = state.revealedText

        state.updateTarget("Hello world", finishing: false)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(afterFirstWord.isEmpty)
        XCTAssertEqual(state.revealedText, "Hello world")
        XCTAssertGreaterThan(growthCount, 0)
    }

    func testSignalsCompleteWhenFinishingAndCaughtUp() async {
        let state = StreamTextRevealState()
        let completeExpectation = expectation(description: "complete")
        state.onComplete = { completeExpectation.fulfill() }

        state.updateTarget("Hi.", finishing: true)
        await fulfillment(of: [completeExpectation], timeout: 2.0)
        XCTAssertEqual(state.revealedText, "Hi.")
    }

    func testResetClearsRevealState() async {
        let state = StreamTextRevealState()
        state.updateTarget("chunk", finishing: false)
        try? await Task.sleep(for: .milliseconds(40))
        state.reset()
        XCTAssertEqual(state.revealedText, "")
        XCTAssertEqual(state.targetText, "")
    }

    func testEmptyTargetClearsRevealedText() {
        let state = StreamTextRevealState()
        state.updateTarget("visible", finishing: false)
        state.updateTarget("", finishing: false)
        XCTAssertEqual(state.revealedText, "")
    }

    func testTargetRewriteKeepsSharedPrefix() async {
        let state = StreamTextRevealState()
        state.updateTarget("Hello world", finishing: false)
        try? await Task.sleep(for: .milliseconds(120))
        state.updateTarget("Hello there", finishing: false)
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(state.revealedText, "Hello there")
    }
}
