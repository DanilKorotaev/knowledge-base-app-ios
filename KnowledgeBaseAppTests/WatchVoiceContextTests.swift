import XCTest
@testable import KnowledgeBaseApp

final class WatchVoiceContextTests: XCTestCase {
    func testParsesDefaultSessionFromApplicationContext() {
        let context: [String: Any] = [
            WatchConnectivityKeys.defaultSessionID: "109",
            WatchConnectivityKeys.defaultSessionTitle: "Wonder",
            WatchConnectivityKeys.expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
            WatchConnectivityKeys.lastResponsePreview: "Hello from assistant",
            WatchConnectivityKeys.relayStatus: WatchRelayStatus.success.rawValue
        ]

        let parsed = WatchVoiceContext(applicationContext: context)

        XCTAssertEqual(parsed.sessionID, "109")
        XCTAssertEqual(parsed.sessionTitle, "Wonder")
        XCTAssertEqual(parsed.lastResponsePreview, "Hello from assistant")
        XCTAssertEqual(parsed.relayStatus, .success)
    }

    func testEmptySessionIDBecomesNil() {
        let parsed = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.defaultSessionID: "",
            WatchConnectivityKeys.defaultSessionTitle: ""
        ])
        XCTAssertNil(parsed.sessionID)
        XCTAssertNil(parsed.sessionTitle)
    }

    func testStripsAnsiEscapeFromPreview() {
        let parsed = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.lastResponsePreview: "Done.\n\u{1B}[?25h"
        ])
        XCTAssertEqual(parsed.lastResponsePreview, "Done.")
    }
}
