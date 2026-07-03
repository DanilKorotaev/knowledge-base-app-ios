import Foundation

/// Persists in-flight voice recordings until transcription succeeds or the user discards.
enum PendingVoiceStore {
    private static let directoryName = "KBPendingVoice"

    static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Copies `sourceURL` into the pending store (survives tmp cleanup).
    @discardableResult
    static func persistRecording(from sourceURL: URL) throws -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let dest = try directoryURL()
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    static func deleteRecording(at url: URL) {
        let root = (try? directoryURL())?.path
        guard let root, url.path.hasPrefix(root) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
