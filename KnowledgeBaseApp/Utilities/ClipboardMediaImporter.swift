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

    /// Loads image attachments from the general pasteboard (async provider load + sync fallbacks).
    static func loadAttachmentsFromPasteboard(
        maxCount: Int = ComposerAttachmentLimits.maxFileAttachments
    ) async -> [PendingAttachment] {
        guard maxCount > 0 else { return [] }

        let delaysNs: [UInt64] = [0, 120_000_000, 280_000_000, 550_000_000, 900_000_000]
        var lastAttempt = 1
        var usedFallback = false
        var source = "none"
        var result: [PendingAttachment] = []

        for (index, delay) in delaysNs.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            lastAttempt = index + 1
            let board = UIPasteboard.general
            if index == 0 {
                ComposerPasteLogger.loadStarted(
                    maxCount: maxCount,
                    hasImages: pasteboardHasImages,
                    providerCount: board.itemProviders.count,
                    types: board.types.joined(separator: ",")
                )
            }

            result = await loadAttachmentsOnce(from: board, maxCount: maxCount)
            if !result.isEmpty {
                source = "providers"
                break
            }

            if let data = pasteboardImageData(from: board),
               let attachment = attachment(fromImageData: data, filename: "paste.jpg") {
                result = [attachment]
                usedFallback = true
                source = "pasteboard-data"
                break
            }

            if let image = board.image,
               let attachment = attachment(fromImage: image, preferredFilename: "paste.jpg") {
                result = [attachment]
                usedFallback = true
                source = "pasteboard-image"
                break
            }
        }

        ComposerPasteLogger.loadFinished(
            count: result.count,
            attempt: lastAttempt,
            usedFallbackImage: usedFallback,
            source: source
        )
        if result.isEmpty, pasteboardHasImages {
            ComposerPasteLogger.loadEmptyAfterRetry(hasImages: true)
        }
        return result
    }

    private static func pasteboardImageData(from board: UIPasteboard) -> Data? {
        let typeCandidates = [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.heic.identifier,
            UTType.heif.identifier,
            UTType.image.identifier,
            "public.png",
            "public.jpeg",
            "public.heic",
            "public.image",
        ]
        for type in typeCandidates {
            if let data = board.data(forPasteboardType: type), !data.isEmpty,
               mimeTypeForImageData(data) != nil || UIImage(data: data) != nil {
                return data
            }
        }
        for item in board.items {
            for (_, value) in item {
                if let data = value as? Data, !data.isEmpty,
                   mimeTypeForImageData(data) != nil || UIImage(data: data) != nil {
                    return data
                }
                if let image = value as? UIImage {
                    return image.jpegData(compressionQuality: 0.92)
                }
            }
        }
        return nil
    }

    private static func loadAttachmentsOnce(
        from board: UIPasteboard,
        maxCount: Int
    ) async -> [PendingAttachment] {
        var result: [PendingAttachment] = []
        for provider in board.itemProviders {
            guard result.count < maxCount else { break }
            guard providerHasImage(provider) else { continue }
            if let attachment = await attachment(from: provider) {
                result.append(attachment)
            }
        }
        return result
    }

    static func attachment(from provider: NSItemProvider) async -> PendingAttachment? {
        if let data = await loadDataRepresentation(from: provider) {
            let filename = suggestedFilename(for: provider, data: data)
            return attachment(fromImageData: data, filename: filename)
        }
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
        let base = displayBaseName(preferredFilename)
        let filename = "\(base).jpg"
        return writeImageAttachment(data: data, filename: filename, mimeType: "image/jpeg")
    }

    static func attachment(
        fromImageData data: Data,
        filename: String,
        mimeType: String? = nil
    ) -> PendingAttachment? {
        guard !data.isEmpty else { return nil }

        let sniffed = mimeTypeForImageData(data)
        let declared = mimeType?.lowercased()
        let looksLikeImage = (sniffed?.hasPrefix("image/") == true)
            || (declared?.hasPrefix("image/") == true)

        // iOS screenshots often arrive as HEIC with a fake pathExtension like "57_PM"
        // (from "9.21.57_PM"). Normalize those to JPEG so thumbnails, Quick Look, and
        // backend mime guessing all work.
        let ext = (filename as NSString).pathExtension.lowercased()
        let hasRealImageExtension = knownImageExtensions.contains(ext)
        let isHeicFamily = sniffed == "image/heic" || sniffed == "image/heif"
            || declared == "image/heic" || declared == "image/heif"
        if isHeicFamily || (looksLikeImage && !hasRealImageExtension),
           let image = UIImage(data: data) {
            return attachment(fromImage: image, preferredFilename: filename)
        }

        let resolvedMime = sniffed
            ?? (declared?.hasPrefix("image/") == true ? declared : nil)
            ?? (hasRealImageExtension ? "image/\(ext == "jpg" ? "jpeg" : ext)" : nil)
        guard let resolvedMime, resolvedMime.hasPrefix("image/") else { return nil }

        let safeName = sanitizedImageFilename(filename, data: data)
        return writeImageAttachment(data: data, filename: safeName, mimeType: resolvedMime)
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

    private static let knownImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp",
    ]

    private static func writeImageAttachment(
        data: Data,
        filename: String,
        mimeType: String
    ) -> PendingAttachment? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
        do {
            try data.write(to: dest)
            return PendingAttachment(
                localURL: dest,
                kind: .image,
                filename: filename,
                mimeType: mimeType,
                fileSize: Int64(data.count)
            )
        } catch {
            return nil
        }
    }

    private static func attachment(fromImageFileURL url: URL) -> PendingAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let filename = url.lastPathComponent.isEmpty ? "paste.jpg" : url.lastPathComponent
        // Prefer magic-byte sniff over pathExtension — screenshot names often end in "57_PM".
        let sniffed = mimeTypeForImageData(data)
        let pathMime = url.kbPreferredMIMEType
        let mime = sniffed ?? (pathMime.hasPrefix("image/") ? pathMime : nil)
        guard let mime, mime.hasPrefix("image/") else {
            // Last resort: UIImage can still decode HEIC without a real extension.
            guard UIImage(data: data) != nil else { return nil }
            return attachment(fromImageData: data, filename: filename, mimeType: "image/heic")
        }
        return attachment(fromImageData: data, filename: filename, mimeType: mime)
    }

    private static func loadDataRepresentation(from provider: NSItemProvider) async -> Data? {
        for type in imageTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(type) {
            let data: Data? = await withCheckedContinuation { continuation in
                _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                    continuation.resume(returning: data)
                }
            }
            if let data, !data.isEmpty {
                return data
            }
        }
        return nil
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
            return sanitizedImageFilename(suggested, data: data)
        }
        let ext = fileExtension(for: data) ?? "jpg"
        return "paste.\(ext)"
    }

    /// Strips fake extensions like `57_PM` and appends a real image extension from sniffed bytes.
    static func sanitizedImageFilename(_ raw: String, data: Data?) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let extFromData = fileExtension(for: data) ?? "jpg"
        if trimmed.isEmpty {
            return "paste.\(extFromData)"
        }
        let ns = trimmed as NSString
        let ext = ns.pathExtension.lowercased()
        if knownImageExtensions.contains(ext) {
            return trimmed
        }
        let base = ext.isEmpty ? trimmed : ns.deletingPathExtension
        let safeBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\((safeBase.isEmpty ? "paste" : safeBase)).\(extFromData)"
    }

    static func displayBaseName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "paste" }
        let ns = trimmed as NSString
        let ext = ns.pathExtension.lowercased()
        if knownImageExtensions.contains(ext) || ext == "jpeg" {
            let base = ns.deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
            return base.isEmpty ? "paste" : base
        }
        if ext.isEmpty {
            return trimmed
        }
        // Fake extension (e.g. "57_PM") — keep the stem before it.
        let base = ns.deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "paste" : base
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

extension UIImage {
    /// Loads an image from disk, falling back to `Data` decode when pathExtension is wrong
    /// (e.g. HEIC screenshot named `…9.21.57_PM`).
    static func kbImage(contentsOf url: URL) -> UIImage? {
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
