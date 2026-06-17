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

    func testStripsAnsiEscapeFromError() {
        let parsed = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.lastResponseError: "Failed[?25h"
        ])
        XCTAssertEqual(parsed.lastResponseError, "Failed")
    }

    func testRelayStatusParsing() {
        let parsed = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.relayStatus: WatchRelayStatus.processing.rawValue
        ])
        XCTAssertEqual(parsed.relayStatus, .processing)
    }

    func testDisplaySessionTitleAndExpiry() {
        let fresh = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.defaultSessionTitle: "Session 125",
            WatchConnectivityKeys.expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        XCTAssertEqual(fresh.displaySessionTitle, "Session 125")
        XCTAssertFalse(fresh.isDefaultExpired)

        let expired = WatchVoiceContext(applicationContext: [
            WatchConnectivityKeys.expiresAt: Date().addingTimeInterval(-10).timeIntervalSince1970
        ])
        XCTAssertEqual(expired.displaySessionTitle, "No voice default")
        XCTAssertTrue(expired.isDefaultExpired)
    }
}
