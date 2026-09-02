import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Loads a Photos picker item as a local file suitable for composer attachments (images + videos).
enum GalleryMediaImporter {
    struct ImportedMedia {
        let localURL: URL
        let kind: PendingAttachmentKind
        let filename: String
        let mimeType: String
        let fileSize: Int64?
    }

    static func importItem(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        if isVideo(item) {
            return try await importVideo(item)
        }
        return try await importImage(item)
    }

    private static func isVideo(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { type in
            type.conforms(to: .audiovisualContent) || type.conforms(to: .movie) || type.conforms(to: .video)
        }
    }

    private static func importImage(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportError.unreadable
        }
        let filename = suggestedFilename(for: item, fallbackExtension: "jpg")
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try data.write(to: dest)
        let mime = dest.kbPreferredMIMEType
        return ImportedMedia(
            localURL: dest,
            kind: .image,
            filename: filename,
            mimeType: mime.hasPrefix("image/") ? mime : "image/jpeg",
            fileSize: Int64(data.count)
        )
    }

    private static func importVideo(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        guard let transferred = try await item.loadTransferable(type: GalleryVideoFile.self) else {
            throw ImportError.unreadable
        }
        let filename = suggestedFilename(for: item, fallbackExtension: transferred.url.pathExtension.isEmpty ? "mp4" : transferred.url.pathExtension)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: transferred.url, to: dest)
        try? FileManager.default.removeItem(at: transferred.url)
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value
        let mime = dest.kbPreferredMIMEType
        return ImportedMedia(
            localURL: dest,
            kind: .video,
            filename: filename,
            mimeType: mime.hasPrefix("video/") ? mime : "video/mp4",
            fileSize: size
        )
    }

    private static func suggestedFilename(for item: PhotosPickerItem, fallbackExtension: String) -> String {
        if let name = item.itemIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return "gallery.\(fallbackExtension)"
    }

    enum ImportError: Error {
        case unreadable
    }
}

private struct GalleryVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try Self.copyReceived(received.file)
        }
        FileRepresentation(contentType: .mpeg4Movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try Self.copyReceived(received.file)
        }
        FileRepresentation(contentType: .quickTimeMovie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try Self.copyReceived(received.file)
        }
        FileRepresentation(contentType: .avi) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            try Self.copyReceived(received.file)
        }
    }

    private static func copyReceived(_ file: URL) throws -> GalleryVideoFile {
        let ext = file.pathExtension.isEmpty ? "mp4" : file.pathExtension
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: copy.path) {
            try FileManager.default.removeItem(at: copy)
        }
        try FileManager.default.copyItem(at: file, to: copy)
        return GalleryVideoFile(url: copy)
    }
}
