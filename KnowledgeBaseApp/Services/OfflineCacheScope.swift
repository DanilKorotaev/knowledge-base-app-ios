import Foundation

/// Resolves offline cache roots as `KBOfflineCache/<host>/u<userId>/…`
/// so accounts (and servers) do not share session/attachment files.
enum OfflineCacheScope {
    static func applicationSupportRoot(fileManager: FileManager = .default) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root.appendingPathComponent("KBOfflineCache", isDirectory: true)
    }

    static func hostKey(from baseURL: URL?) -> String {
        let host = baseURL?.host?.lowercased() ?? "default"
        let port = baseURL?.port.map(String.init) ?? ""
        let raw = port.isEmpty ? host : "\(host)_\(port)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let key = String(filtered)
        return key.isEmpty ? "default" : key
    }

    static func userKey(userId: Int?) -> String {
        guard let userId else { return "anonymous" }
        return "u\(userId)"
    }

    /// Sessions + messages live under this directory.
    /// Pass `userId` explicitly — do not read `AuthSessionStore.shared` here (init cycles).
    static func storeRoot(
        apiBaseURL: URL?,
        userId: Int?,
        fileManager: FileManager = .default
    ) -> URL {
        applicationSupportRoot(fileManager: fileManager)
            .appendingPathComponent(hostKey(from: apiBaseURL), isDirectory: true)
            .appendingPathComponent(userKey(userId: userId), isDirectory: true)
    }

    /// Attachment bytes under `…/attachments`.
    static func attachmentsRoot(
        apiBaseURL: URL?,
        userId: Int?,
        fileManager: FileManager = .default
    ) -> URL {
        storeRoot(apiBaseURL: apiBaseURL, userId: userId, fileManager: fileManager)
            .appendingPathComponent("attachments", isDirectory: true)
    }
}
