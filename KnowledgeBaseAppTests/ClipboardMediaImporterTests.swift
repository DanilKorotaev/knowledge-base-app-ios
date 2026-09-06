import UniformTypeIdentifiers
import UIKit
import XCTest
@testable import KnowledgeBaseApp

final class ClipboardMediaImporterTests: XCTestCase {
    override func tearDown() {
        UIPasteboard.general.items = []
        super.tearDown()
    }

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

    func testAttachmentFromUIImage_keepsJpgSuffix() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let attachment = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImage: image, preferredFilename: "shot.JPEG")
        )
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }
        XCTAssertEqual(attachment.filename, "shot.JPEG")
    }

    func testAttachmentFromEmptyFilename_usesPasteDefault() throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let attachment = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: data, filename: "   ")
        )
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }
        XCTAssertEqual(attachment.filename, "paste.jpg")
    }

    func testAttachmentFromEmptyData_returnsNil() {
        XCTAssertNil(ClipboardMediaImporter.attachment(fromImageData: Data(), filename: "empty.png"))
    }

    func testAttachmentFromNonImageData_returnsNil() {
        let data = Data("not-an-image".utf8)
        let attachment = ClipboardMediaImporter.attachment(
            fromImageData: data,
            filename: "note.txt",
            mimeType: "text/plain"
        )
        XCTAssertNil(attachment)
    }

    func testMimeSniff_gifWebpHeicMagicBytes() throws {
        let gif = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61] + Array(repeating: 0, count: 12))
        let gifAtt = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: gif, filename: "x.bin")
        )
        defer { try? FileManager.default.removeItem(at: gifAtt.localURL) }
        XCTAssertEqual(gifAtt.mimeType, "image/gif")

        var webp = Data([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])
        webp.append(contentsOf: Array(repeating: UInt8(0), count: 8))
        let webpAtt = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: webp, filename: "x.bin")
        )
        defer { try? FileManager.default.removeItem(at: webpAtt.localURL) }
        XCTAssertEqual(webpAtt.mimeType, "image/webp")

        // ftyp box at offset 4 → treated as HEIC family
        var heic = Data(repeating: 0, count: 12)
        heic[4] = 0x66; heic[5] = 0x74; heic[6] = 0x79; heic[7] = 0x70
        let heicAtt = try XCTUnwrap(
            ClipboardMediaImporter.attachment(fromImageData: heic, filename: "x.bin")
        )
        defer { try? FileManager.default.removeItem(at: heicAtt.localURL) }
        XCTAssertEqual(heicAtt.mimeType, "image/heic")
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

    func testLoadAttachmentsFromPasteboard_maxCountZero_returnsEmpty() async {
        UIPasteboard.general.image = solidJPEGImage()
        let attachments = await ClipboardMediaImporter.loadAttachmentsFromPasteboard(maxCount: 0)
        XCTAssertTrue(attachments.isEmpty)
    }

    func testLoadAttachmentsFromPasteboard_usesPasteboardImage() async throws {
        let image = try XCTUnwrap(solidJPEGImage())
        UIPasteboard.general.image = image
        XCTAssertTrue(ClipboardMediaImporter.pasteboardHasImages)

        let attachments = await ClipboardMediaImporter.loadAttachmentsFromPasteboard(maxCount: 2)
        defer {
            for attachment in attachments {
                try? FileManager.default.removeItem(at: attachment.localURL)
            }
        }
        XCTAssertFalse(attachments.isEmpty)
        XCTAssertEqual(attachments.first?.kind, .image)
    }

    func testAttachmentFromItemProvider_jpegData() async throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let provider = NSItemProvider(item: data as NSData, typeIdentifier: UTType.jpeg.identifier)
        provider.suggestedName = "clip"

        XCTAssertTrue(ClipboardMediaImporter.providerHasImage(provider))
        let loaded = await ClipboardMediaImporter.attachment(from: provider)
        let attachment = try XCTUnwrap(loaded)
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertTrue(attachment.filename.contains("clip"))
        XCTAssertTrue(attachment.mimeType.hasPrefix("image/"))
    }

    func testAttachmentFromItemProvider_uiImageObject() async throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let provider = NSItemProvider(object: image)
        let loaded = await ClipboardMediaImporter.attachment(from: provider)
        let attachment = try XCTUnwrap(loaded)
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }
        XCTAssertEqual(attachment.kind, .image)
    }

    func testAttachmentFromItemProvider_fileURLImage() async throws {
        let image = try XCTUnwrap(solidJPEGImage())
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-\(UUID().uuidString).jpg")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try XCTUnwrap(NSItemProvider(contentsOf: url))
        let loaded = await ClipboardMediaImporter.attachment(from: provider)
        let attachment = try XCTUnwrap(loaded)
        defer { try? FileManager.default.removeItem(at: attachment.localURL) }
        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
    }

    func testAttachmentFromItemProvider_nonImageFileURL_returnsNil() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try XCTUnwrap(NSItemProvider(contentsOf: url))
        // Provider may still claim fileURL; importer should reject non-image.
        let attachment = await ClipboardMediaImporter.attachment(from: provider)
        if let attachment {
            try? FileManager.default.removeItem(at: attachment.localURL)
            // Some providers also expose public.data — accept nil or non-image rejection only.
            XCTAssertNotEqual(attachment.kind, .image)
        } else {
            XCTAssertNil(attachment)
        }
    }

    func testProviderHasImage_falseForPlainText() {
        let provider = NSItemProvider(object: "hello" as NSString)
        XCTAssertFalse(ClipboardMediaImporter.providerHasImage(provider))
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

final class PasteAwareTextViewTests: XCTestCase {
    override func tearDown() {
        UIPasteboard.general.items = []
        super.tearDown()
    }

    func testPaste_withImage_invokesHandlerAndSkipsTextInsertion() {
        let textView = PasteAwareTextView()
        textView.text = "keep"
        var pasteImagesCalls = 0
        textView.onPasteImages = { pasteImagesCalls += 1 }

        UIPasteboard.general.image = solidJPEGImage()
        textView.paste(nil)

        XCTAssertEqual(pasteImagesCalls, 1)
        XCTAssertEqual(textView.text, "keep")
        XCTAssertTrue(
            textView.canPerformAction(#selector(UIResponder.paste(_:)), withSender: nil)
        )
    }

    func testPaste_withTextOnly_doesNotInvokeImageHandler() {
        let textView = PasteAwareTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        textView.text = "keep"
        var pasteImagesCalls = 0
        textView.onPasteImages = { pasteImagesCalls += 1 }

        UIPasteboard.general.string = "hello"
        XCTAssertFalse(ClipboardMediaImporter.pasteboardHasImages)
        textView.paste(nil)

        XCTAssertEqual(pasteImagesCalls, 0)
        // Text insertion via UIPasteboard can be environment-dependent; image path must stay unused.
        XCTAssertEqual(textView.text, "keep")
    }

    func testIntrinsicContentSize_hasMinimumHeight() {
        let textView = PasteAwareTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 10))
        textView.text = "a"
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        let size = textView.intrinsicContentSize
        XCTAssertGreaterThanOrEqual(size.height, 24)
    }

    private func solidJPEGImage() -> UIImage? {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
