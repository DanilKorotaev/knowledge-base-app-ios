import Foundation
import UniformTypeIdentifiers

enum CachedAttachmentKind: Equatable {
    case image
    case audio
    case video
    case other

    static func from(entry: CachedAttachmentEntry, dataHint: Data? = nil) -> CachedAttachmentKind {
        if let mime = entry.mimeType?.lowercased() {
            if mime.hasPrefix("image/") { return .image }
            if mime.hasPrefix("audio/") { return .audio }
            if mime.hasPrefix("video/") { return .video }
        }

        let name = (entry.fileName ?? "").lowercased()
        let ext = (name as NSString).pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        }

        if let dataHint, let sniffed = sniff(data: dataHint) {
            return sniffed
        }

        return .other
    }

    static func sniff(data: Data) -> CachedAttachmentKind? {
        guard data.count >= 12 else { return nil }
        let bytes = [UInt8](data.prefix(12))
        // JPEG
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF { return .image }
        // PNG
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return .image }
        // GIF
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return .image }
        // WebP
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]), data.count >= 12 {
            let riff = data.subdata(in: 8..<12)
            if String(data: riff, encoding: .ascii) == "WEBP" { return .image }
        }
        // MP4 / M4A / MOV (ftyp)
        if bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
            let brand = String(data: data.subdata(in: 8..<min(12, data.count)), encoding: .ascii) ?? ""
            if brand.hasPrefix("M4A") || brand.hasPrefix("mp4a") {
                return .audio
            }
            return .video
        }
        // ID3 / MP3
        if bytes.starts(with: [0x49, 0x44, 0x33]) { return .audio }
        if bytes[0] == 0xFF, (bytes[1] & 0xE0) == 0xE0 { return .audio }
        return nil
    }

    var systemImageName: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .other: return "doc"
        }
    }

    var preferredFilenameExtension: String {
        switch self {
        case .image: return "jpg"
        case .audio: return "m4a"
        case .video: return "mp4"
        case .other: return "bin"
        }
    }
}

enum CachedAttachmentPreviewURL {
    /// Copy cache blob to a temp file with a human-readable name + extension so Quick Look / AVPlayer work.
    static func make(
        for entry: CachedAttachmentEntry,
        sourceURL: URL,
        kind: CachedAttachmentKind
    ) throws -> URL {
        let fileName = displayFileName(for: entry, kind: kind)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-cache-\(UUID().uuidString)-\(fileName)")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    static func displayFileName(for entry: CachedAttachmentEntry, kind: CachedAttachmentKind) -> String {
        if let name = entry.fileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            if (name as NSString).pathExtension.isEmpty {
                return "\(name).\(kind.preferredFilenameExtension)"
            }
            return name
        }
        if let mime = entry.mimeType, let type = UTType(mimeType: mime),
           let ext = type.preferredFilenameExtension {
            return "attachment.\(ext)"
        }
        let shortKey = entry.cacheKey.split(separator: "/").last.map(String.init) ?? "attachment"
        return "\(shortKey).\(kind.preferredFilenameExtension)"
    }

    static func displayTitle(for entry: CachedAttachmentEntry, kind: CachedAttachmentKind) -> String {
        if let name = entry.fileName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return displayFileName(for: entry, kind: kind)
    }
}
