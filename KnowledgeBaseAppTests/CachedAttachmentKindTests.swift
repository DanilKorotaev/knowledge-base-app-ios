import XCTest
@testable import KnowledgeBaseApp

final class CachedAttachmentKindTests: XCTestCase {
    func testDetectsImageFromMimeType() {
        let entry = CachedAttachmentEntry(
            cacheKey: "a",
            fileName: "photo.bin",
            mimeType: "image/jpeg",
            byteSize: 10,
            sessionId: nil,
            messageId: nil,
            lastAccessAt: Date(),
            createdAt: Date()
        )
        XCTAssertEqual(CachedAttachmentKind.from(entry: entry), .image)
    }

    func testDetectsAudioFromExtension() {
        let entry = CachedAttachmentEntry(
            cacheKey: "b",
            fileName: "voice.m4a",
            mimeType: nil,
            byteSize: 10,
            sessionId: nil,
            messageId: nil,
            lastAccessAt: Date(),
            createdAt: Date()
        )
        XCTAssertEqual(CachedAttachmentKind.from(entry: entry), .audio)
    }

    func testDetectsVideoFromMimeType() {
        let entry = CachedAttachmentEntry(
            cacheKey: "c",
            fileName: "clip.mp4",
            mimeType: "video/mp4",
            byteSize: 10,
            sessionId: nil,
            messageId: nil,
            lastAccessAt: Date(),
            createdAt: Date()
        )
        XCTAssertEqual(CachedAttachmentKind.from(entry: entry), .video)
    }
}

final class KBAttachmentMediaKindTests: XCTestCase {
    func testVideoAttachmentDetection() {
        let attachment = KBAttachment(
            id: "1",
            fileType: "video",
            fileName: "clip.mp4",
            fileSize: 100,
            mimeType: "video/mp4",
            downloadURL: "/api/sessions/1/attachments/1/file",
            transcription: nil
        )
        XCTAssertTrue(attachment.isVideo)
        XCTAssertFalse(attachment.isVoice)
    }
}
