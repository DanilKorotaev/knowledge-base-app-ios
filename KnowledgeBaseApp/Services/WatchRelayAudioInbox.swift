import Foundation

enum WatchRelayAudioInbox {
    static func copyIncomingAudio(from source: URL, recordingID: String) -> URL? {
        let sourceExists = FileManager.default.fileExists(atPath: source.path)
        let sourceBytes = sourceExists
            ? (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.intValue ?? 0
            : 0
        guard sourceExists, sourceBytes > 0 else {
            WatchRelayLogger.error(
                "copyIncomingAudio source missing recordingId=\(recordingID) path=\(source.lastPathComponent) exists=\(sourceExists) bytes=\(sourceBytes)"
            )
            return nil
        }
        let inbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-relay-inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let destination = inbox.appendingPathComponent("\(recordingID).m4a")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            let bytes = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? 0
            WatchRelayLogger.info("Copied relay audio recordingId=\(recordingID) bytes=\(bytes)")
            return destination
        } catch {
            WatchRelayLogger.error("copyIncomingAudio failed recordingId=\(recordingID): \(error.localizedDescription)")
            return nil
        }
    }
}
