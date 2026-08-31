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

    func testSniffsJPEGMagicBytes() {
        let entry = CachedAttachmentEntry(
            cacheKey: "api/sessions/1/attachments/2/file",
            fileName: nil,
            mimeType: nil,
            byteSize: 4,
            sessionId: "1",
            messageId: "2",
            lastAccessAt: Date(),
            createdAt: Date()
        )
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
        XCTAssertEqual(CachedAttachmentKind.from(entry: entry, dataHint: jpegHeader), .image)
    }

    func testPreviewURLUsesReadableFilename() throws {
        let entry = CachedAttachmentEntry(
            cacheKey: "api/sessions/51/attachments/482/file",
            fileName: nil,
            mimeType: "image/jpeg",
            byteSize: 12,
            sessionId: "51",
            messageId: "482",
            lastAccessAt: Date(),
            createdAt: Date()
        )
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-src-\(UUID().uuidString).dat")
        let payload = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
        try payload.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let preview = try CachedAttachmentPreviewURL.make(
            for: entry,
            sourceURL: source,
            kind: .image
        )
        defer { try? FileManager.default.removeItem(at: preview) }

        XCTAssertEqual(preview.pathExtension, "jpg")
        XCTAssertFalse(preview.lastPathComponent.contains("YXBp"))
        XCTAssertEqual(try Data(contentsOf: preview), payload)
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
