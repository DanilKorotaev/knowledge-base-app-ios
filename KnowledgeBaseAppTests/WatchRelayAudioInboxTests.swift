import XCTest
@testable import KnowledgeBaseApp

final class WatchRelayAudioInboxTests: XCTestCase {
    func testCopyIncomingAudio_copiesBytesToInbox() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-source-\(UUID().uuidString).m4a")
        let payload = Data(repeating: 0xCD, count: 64)
        try payload.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let recordingID = UUID().uuidString
        let copied = try XCTUnwrap(WatchRelayAudioInbox.copyIncomingAudio(from: source, recordingID: recordingID))
        defer { try? FileManager.default.removeItem(at: copied) }

        XCTAssertEqual(copied.lastPathComponent, "\(recordingID).m4a")
        XCTAssertEqual(try Data(contentsOf: copied), payload)
    }

    func testCopyIncomingAudio_returnsNilForMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).m4a")

        XCTAssertNil(WatchRelayAudioInbox.copyIncomingAudio(from: missing, recordingID: "rec-1"))
    }

    func testCopyIncomingAudio_overwritesExistingDestination() throws {
        let recordingID = UUID().uuidString
        let inbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-relay-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let destination = inbox.appendingPathComponent("\(recordingID).m4a")
        try Data([0x01]).write(to: destination)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-source-\(UUID().uuidString).m4a")
        let payload = Data(repeating: 0xFE, count: 32)
        try payload.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let copied = try XCTUnwrap(WatchRelayAudioInbox.copyIncomingAudio(from: source, recordingID: recordingID))
        defer { try? FileManager.default.removeItem(at: copied) }

        XCTAssertEqual(try Data(contentsOf: copied), payload)
    }
}
