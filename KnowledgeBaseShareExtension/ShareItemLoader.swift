import Foundation
import UIKit
import UniformTypeIdentifiers

struct SharePayload: Equatable {
    var text: String = ""
    var attachments: [PendingAttachment] = []
}

enum ShareItemLoader {
    static func load(from extensionContext: NSExtensionContext?) async -> SharePayload {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return SharePayload()
        }

        var textParts: [String] = []
        var attachments: [PendingAttachment] = []
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-share-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if let urlText = await loadURLString(from: provider) {
                    textParts.append(urlText)
                    continue
                }
                if let plain = await loadPlainText(from: provider) {
                    textParts.append(plain)
                    continue
                }
                if let attachment = await loadFileAttachment(from: provider, into: scratch) {
                    if ComposerAttachmentLimits.validateAdding(
                        currentAttachments: attachments,
                        newAttachment: attachment
                    ) == nil {
                        attachments.append(attachment)
                    }
                }
            }
        }

        var payload = SharePayload()
        payload.text = textParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        payload.attachments = attachments
        return payload
    }

    private static func loadPlainText(from provider: NSItemProvider) async -> String? {
        let type = UTType.plainText.identifier
        guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let string = item as? String {
                    continuation.resume(returning: string)
                } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: string)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadURLString(from provider: NSItemProvider) async -> String? {
        let type = UTType.url.identifier
        guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL, !url.isFileURL {
                    continuation.resume(returning: url.absoluteString)
                } else if let string = item as? String {
                    continuation.resume(returning: string)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadFileAttachment(
        from provider: NSItemProvider,
        into directory: URL
    ) async -> PendingAttachment? {
        let imageTypes = [UTType.image.identifier, UTType.jpeg.identifier, UTType.png.identifier, UTType.heic.identifier]
        for type in imageTypes where provider.hasItemConformingToTypeIdentifier(type) {
            if let attachment = await copyProviderItem(provider, typeIdentifier: type, into: directory, preferImage: true) {
                return attachment
            }
        }

        let fileTypes = [UTType.fileURL.identifier, UTType.pdf.identifier, UTType.data.identifier]
        for type in fileTypes where provider.hasItemConformingToTypeIdentifier(type) {
            if let attachment = await copyProviderItem(provider, typeIdentifier: type, into: directory, preferImage: false) {
                return attachment
            }
        }
        return nil
    }

    private static func copyProviderItem(
        _ provider: NSItemProvider,
        typeIdentifier: String,
        into directory: URL,
        preferImage: Bool
    ) async -> PendingAttachment? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let result = materializeAttachment(item: item, into: directory, preferImage: preferImage)
                continuation.resume(returning: result)
            }
        }
    }

    private static func materializeAttachment(
        item: NSSecureCoding?,
        into directory: URL,
        preferImage: Bool
    ) -> PendingAttachment? {
        let fileManager = FileManager.default

        if let url = item as? URL {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url) else { return nil }
            let filename = url.lastPathComponent.isEmpty ? "share.bin" : url.lastPathComponent
            let dest = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
            do {
                try data.write(to: dest)
            } catch {
                return nil
            }
            let mime = dest.kbPreferredMIMEType
            let kind: PendingAttachmentKind = preferImage || mime.hasPrefix("image/") ? .image : .file
            let size = (try? fileManager.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value
            return PendingAttachment(
                localURL: dest,
                kind: kind,
                filename: filename,
                mimeType: mime,
                fileSize: size
            )
        }

        if let data = item as? Data {
            let ext = preferImage ? "jpg" : "bin"
            let filename = "share.\(ext)"
            let dest = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
            do {
                try data.write(to: dest)
            } catch {
                return nil
            }
            let mime = dest.kbPreferredMIMEType
            let kind: PendingAttachmentKind = preferImage || mime.hasPrefix("image/") ? .image : .file
            return PendingAttachment(
                localURL: dest,
                kind: kind,
                filename: filename,
                mimeType: mime,
                fileSize: Int64(data.count)
            )
        }

        if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
            let filename = "share.jpg"
            let dest = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
            do {
                try data.write(to: dest)
            } catch {
                return nil
            }
            return PendingAttachment(
                localURL: dest,
                kind: .image,
                filename: filename,
                mimeType: "image/jpeg",
                fileSize: Int64(data.count)
            )
        }

        return nil
    }
}
