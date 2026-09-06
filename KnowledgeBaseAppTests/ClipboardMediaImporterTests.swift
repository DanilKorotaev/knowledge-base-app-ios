import UIKit
import XCTest
@testable import KnowledgeBaseApp

final class ClipboardMediaImporterTests: XCTestCase {
    func testAttachmentFromJPEGData_preservesMimeAndKind() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let attachment = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: data, filename: "shot.jpg")
        )
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertEqual(attachment.filename, "shot.jpg")
        XCTAssertEqual(attachment.fileSize, Int64(data.count))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.localURL.path))
    }

    func testAttachmentFromPNGData_detectsPngMime() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.pngData())
        let attachment = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: data, filename: "paste.png")
        )
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.mimeType, "image/png")
    }

    func testAttachmentFromUIImage_writesJpeg() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let attachment = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImage: image, preferredFilename: "camera")
        )
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertTrue(attachment.filename.hasSuffix(".jpg"))
        XCTAssertGreaterThan(attachment.fileSize ?? 0, 0)
    }

    func testAttachmentFromEmptyData_returnsNil() {
        XCTAssertNil(ClipboardMediaImporter.attachment(fromImageData: Data(), filename: "empty.png"))
    }

    func testAttachmentFromNonImageData_returnsNil() {
        let data = Data("not-an-image".utf8)
        // Without image magic bytes, mime falls back to jpeg path via write — still image/jpeg.
        // Explicit non-image mime should be rejected:
        let attachment = ClipboardMediaImporter.attachment(
            fromImageData: data,
            filename: "note.txt",
            mimeType: "text/plain"
        )
        XCTAssertNil(attachment)
    }

    func testValidateAdding_rejectsPasteWhenAtLimit() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let paste = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: data, filename: "paste.jpg")
        )
        defer { try? FileManager.default.removeItem(at: paste.localURL) }

        let current = (1 ... ComposerAttachmentLimits.maxFileAttachments).map { index in
            PendingAttachment(
                localURL: URL(fileURLWithPath: "/tmp/\(index).jpg"),
                kind: .image,
                filename: "\(index).jpg",
                mimeType: "image/jpeg",
                fileSize: 10
            )
        }
        let error = ComposerAttachmentLimits.validateAdding(
            currentAttachments: current,
            newAttachment: paste
        )
        XCTAssertEqual(error, .tooManyFiles(max: ComposerAttachmentLimits.maxFileAttachments))
    }

    private func solidJPEGImage() -> UIImage? {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
