import Foundation
import UniformTypeIdentifiers

enum CachedAttachmentKind: Equatable {
    case image
    case audio
    case video
    case other

    static func from(entry: CachedAttachmentEntry) -> CachedAttachmentKind {
        if let mime = entry.mimeType?.lowercased() {
            if mime.hasPrefix("image/") { return .image }
            if mime.hasPrefix("audio/") { return .audio }
            if mime.hasPrefix("video/") { return .video }
        }

        let name = (entry.fileName ?? entry.cacheKey).lowercased()
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return .other
        }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        return .other
    }

    var systemImageName: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .other: return "doc"
        }
    }
}
