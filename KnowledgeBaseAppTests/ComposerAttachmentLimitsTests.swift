import XCTest
@testable import KnowledgeBaseApp

final class ComposerAttachmentLimitsTests: XCTestCase {
    private func attachment(filename: String, size: Int64? = nil) -> PendingAttachment {
        PendingAttachment(
            localURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            kind: .file,
            filename: filename,
            mimeType: "application/octet-stream",
            fileSize: size
        )
    }

    func testValidateAdding_rejectsEleventhAttachment() {
        let current = (1 ... 10).map { attachment(filename: "\($0).txt") }
        let error = ComposerAttachmentLimits.validateAdding(
            currentAttachments: current,
            newAttachment: attachment(filename: "11.txt")
        )
        XCTAssertEqual(error, .tooManyFiles(max: 10))
    }

    func testValidateAdding_rejectsOversizedFile() {
        let max = ComposerAttachmentLimits.maxBytesPerAttachment
        let error = ComposerAttachmentLimits.validateAdding(
            currentAttachments: [],
            newAttachment: attachment(filename: "big.bin", size: max + 1)
        )
        XCTAssertEqual(error, .fileTooLarge(filename: "big.bin", maxBytes: max))
    }

    func testValidateAdding_acceptsFileAtLimit() {
        let max = ComposerAttachmentLimits.maxBytesPerAttachment
        let error = ComposerAttachmentLimits.validateAdding(
            currentAttachments: [],
            newAttachment: attachment(filename: "ok.bin", size: max)
        )
        XCTAssertNil(error)
    }

    func testRemainingFileSlots() {
        XCTAssertEqual(ComposerAttachmentLimits.remainingFileSlots(currentCount: 0), 10)
        XCTAssertEqual(ComposerAttachmentLimits.remainingFileSlots(currentCount: 9), 1)
        XCTAssertEqual(ComposerAttachmentLimits.remainingFileSlots(currentCount: 10), 0)
        XCTAssertEqual(ComposerAttachmentLimits.remainingFileSlots(currentCount: 11), 0)
    }

    func testValidationErrorMessagesAreEnglish() {
        XCTAssertTrue(
            ComposerAttachmentLimits.ValidationError.tooManyFiles(max: 10).message.contains("10")
        )
        XCTAssertTrue(
            ComposerAttachmentLimits.ValidationError.fileTooLarge(
                filename: "doc.pdf",
                maxBytes: 1024
            ).message.contains("doc.pdf")
        )
    }
}

final class AttachmentPreviewURLResolverTests: XCTestCase {
    func testResolveLocalURL_usesFileURLDirectly() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-test.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let attachment = KBAttachment(
            id: "1",
            fileType: "document",
            fileName: "preview-test.txt",
            fileSize: 5,
            mimeType: "text/plain",
            downloadURL: fileURL.absoluteString,
            transcription: nil
        )

        let resolved = try await AttachmentPreviewURLResolver.resolveLocalURL(
            for: attachment,
            loader: nil
        )
        XCTAssertEqual(resolved, fileURL)
    }

    func testResolveLocalURL_downloadsViaLoader() async throws {
        let attachment = KBAttachment(
            id: "2",
            fileType: "document",
            fileName: "remote.txt",
            fileSize: 4,
            mimeType: "text/plain",
            downloadURL: "/api/sessions/1/attachments/2/file",
            transcription: nil
        )

        let loader = PreviewStubLoader(payload: Data("test".utf8))
        let resolved = try await AttachmentPreviewURLResolver.resolveLocalURL(
            for: attachment,
            loader: loader
        )
        defer { try? FileManager.default.removeItem(at: resolved) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
        XCTAssertEqual(try Data(contentsOf: resolved), Data("test".utf8))
    }
}

private struct PreviewStubLoader: KBAttachmentLoaderProtocol {
    let payload: Data

    func absoluteURL(for downloadPath: String) -> URL? {
        URL(string: "https://example.com\(downloadPath)")
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        payload
    }
}
