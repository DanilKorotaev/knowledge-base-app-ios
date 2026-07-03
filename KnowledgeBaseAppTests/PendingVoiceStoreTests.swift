import XCTest
@testable import KnowledgeBaseApp

final class PendingVoiceStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-voice-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testPersistRecordingCopiesSourceFile() throws {
        let source = tempRoot.appendingPathComponent("source.m4a")
        try Data("audio".utf8).write(to: source)

        let persisted = try PendingVoiceStore.persistRecording(from: source)

        XCTAssertNotEqual(persisted, source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: persisted.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testDeleteRecordingRemovesOnlyPendingStoreFiles() throws {
        let source = tempRoot.appendingPathComponent("source.m4a")
        try Data("audio".utf8).write(to: source)
        let persisted = try PendingVoiceStore.persistRecording(from: source)

        PendingVoiceStore.deleteRecording(at: persisted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: persisted.path))

        let outside = tempRoot.appendingPathComponent("outside.m4a")
        try Data("x".utf8).write(to: outside)
        PendingVoiceStore.deleteRecording(at: outside)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
}
