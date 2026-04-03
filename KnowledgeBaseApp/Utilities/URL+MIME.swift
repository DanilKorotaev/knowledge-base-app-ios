import Foundation

extension URL {
    /// Rough MIME for multipart uploads (KB App API will validate).
    var kbPreferredMIMEType: String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic", "heif": return "image/heic"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        default: return "application/octet-stream"
        }
    }
}
