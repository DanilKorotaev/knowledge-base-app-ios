import Foundation

/// Safety rules for Structured UI `link` / remote `image` URLs.
enum StructuredUIURLPolicy {
    /// Public http(s) URLs only (no `javascript:`, `file:`, custom schemes).
    static func allowedHTTPURL(from raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        guard scheme == "https" || scheme == "http" else {
            return nil
        }
        guard url.host != nil else {
            return nil
        }
        return url
    }

    /// Relative or absolute API download paths used with `KBAttachmentLoaderProtocol`.
    static func isAllowedDownloadPath(_ raw: String?) -> Bool {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        if raw.contains("..") { return false }
        if raw.hasPrefix("file://") { return true }
        if raw.hasPrefix("/") { return true }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return allowedHTTPURL(from: raw) != nil
        }
        // Reject other URI schemes (`javascript:`, `data:`, …).
        if let schemeEnd = raw.firstIndex(of: ":"),
           raw[raw.startIndex..<schemeEnd].allSatisfy({ $0.isLetter }) {
            return false
        }
        // Relative API paths like `api/attachments/...`
        return true
    }
}
