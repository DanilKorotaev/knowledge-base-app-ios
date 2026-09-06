import Foundation
import UIKit
import UniformTypeIdentifiers

/// Materializes clipboard / drop image providers into composer `PendingAttachment`s (images only).
enum ClipboardMediaImporter {
    static var pasteboardHasImages: Bool {
        let board = UIPasteboard.general
        if board.hasImages { return true }
        return board.itemProviders.contains { providerHasImage($0) }
    }

    /// Loads image attachments from the general pasteboard (async provider load + sync UIImage fallback).
    static func loadAttachmentsFromPasteboard(
        maxCount: Int = ComposerAttachmentLimits.maxFileAttachments
    ) async -> [PendingAttachment] {
        guard maxCount > 0 else { return [] }
        let board = UIPasteboard.general
        var result: [PendingAttachment] = []

        for provider in board.itemProviders {
            guard result.count < maxCount else { break }
            guard providerHasImage(provider) else { continue }
            if let attachment = await attachment(from: provider) {
                result.append(attachment)
            }
        }

        if result.isEmpty, let image = board.image,
           let attachment = attachment(fromImage: image, preferredFilename: "paste.jpg") {
            result.append(attachment)
        }

        return result
    }

    static func attachment(from provider: NSItemProvider) async -> PendingAttachment? {
        if let data = await loadImageData(from: provider) {
            let filename = suggestedFilename(for: provider, data: data)
            return attachment(fromImageData: data, filename: filename)
        }
        if let image = await loadUIImage(from: provider) {
            return attachment(fromImage: image, preferredFilename: suggestedFilename(for: provider, data: nil))
        }
        if let url = await loadFileURL(from: provider) {
            return attachment(fromImageFileURL: url)
        }
        return nil
    }

    static func attachment(
        fromImage image: UIImage,
        preferredFilename: String = "paste.jpg"
    ) -> PendingAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let filename = preferredFilename.lowercased().hasSuffix(".jpg") || preferredFilename.lowercased().hasSuffix(".jpeg")
            ? preferredFilename
            : "\(preferredFilename).jpg"
        return attachment(fromImageData: data, filename: filename, mimeType: "image/jpeg")
    }

    static func attachment(
        fromImageData data: Data,
        filename: String,
        mimeType: String? = nil
    ) -> PendingAttachment? {
        guard !data.isEmpty else { return nil }
        let safeName = filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "paste.jpg"
            : filename
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(safeName)")
        do {
            try data.write(to: dest)
            let mime = mimeType
                ?? (dest.kbPreferredMIMEType.hasPrefix("image/")
                    ? dest.kbPreferredMIMEType
                    : mimeTypeForImageData(data) ?? "image/jpeg")
            guard mime.hasPrefix("image/") else {
                try? FileManager.default.removeItem(at: dest)
                return nil
            }
            return PendingAttachment(
                localURL: dest,
                kind: .image,
                filename: safeName,
                mimeType: mime,
                fileSize: Int64(data.count)
            )
        } catch {
            return nil
        }
    }

    static func providerHasImage(_ provider: NSItemProvider) -> Bool {
        imageTypeIdentifiers.contains { provider.hasItemConformingToTypeIdentifier($0) }
    }

    // MARK: - Private

    private static let imageTypeIdentifiers: [String] = [
        UTType.image.identifier,
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.heic.identifier,
        UTType.heif.identifier,
        UTType.gif.identifier,
        UTType.webP.identifier,
    ]

    private static func attachment(fromImageFileURL url: URL) -> PendingAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        let ext = url.pathExtension.lowercased()
        let kind = PendingAttachmentKind.infer(mimeType: url.kbPreferredMIMEType, filenameExtension: ext)
        guard kind == .image else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let filename = url.lastPathComponent.isEmpty ? "paste.jpg" : url.lastPathComponent
        return attachment(fromImageData: data, filename: filename, mimeType: url.kbPreferredMIMEType)
    }

    private static func loadImageData(from provider: NSItemProvider) async -> Data? {
        for type in imageTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(type) {
            if let data = await loadData(from: provider, typeIdentifier: type) {
                return data
            }
        }
        return nil
    }

    private static func loadUIImage(from provider: NSItemProvider) async -> UIImage? {
        let type = UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else if let data = item as? Data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        let type = UTType.fileURL.identifier
        guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadData(from provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let data = item as? Data {
                    continuation.resume(returning: data)
                } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    continuation.resume(returning: data)
                } else if let image = item as? UIImage {
                    continuation.resume(returning: image.pngData() ?? image.jpegData(compressionQuality: 0.92))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func suggestedFilename(for provider: NSItemProvider, data: Data?) -> String {
        if let suggested = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggested.isEmpty {
            if (suggested as NSString).pathExtension.isEmpty {
                let ext = fileExtension(for: data) ?? "jpg"
                return "\(suggested).\(ext)"
            }
            return suggested
        }
        let ext = fileExtension(for: data) ?? "jpg"
        return "paste.\(ext)"
    }

    private static func fileExtension(for data: Data?) -> String? {
        guard let data, let mime = mimeTypeForImageData(data) else { return nil }
        switch mime {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/heic", "image/heif": return "heic"
        default: return nil
        }
    }

    private static func mimeTypeForImageData(_ data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if bytes.count >= 12,
           Array(bytes[4 ..< 8]) == [0x66, 0x74, 0x79, 0x70] { // ftyp → HEIC/HEIF family
            return "image/heic"
        }
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(bytes[8 ..< 12]) == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }
        return nil
    }
}
