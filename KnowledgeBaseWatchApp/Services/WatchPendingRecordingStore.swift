import Foundation

struct WatchPendingRecording: Codable, Identifiable, Equatable {
    let id: String
    let fileName: String
    let createdAt: Date
    var sessionID: String?
}

@MainActor
final class WatchPendingRecordingStore {
    static let shared = WatchPendingRecordingStore()

    private let directoryName = "pending-watch-recordings"
    private let indexFileName = "index.json"

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var indexURL: URL {
        directoryURL.appendingPathComponent(indexFileName)
    }

    func loadAll() -> [WatchPendingRecording] {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([WatchPendingRecording].self, from: data) else {
            return []
        }
        return list.sorted { $0.createdAt < $1.createdAt }
    }

    func saveRecording(from sourceURL: URL, sessionID: String?) throws -> WatchPendingRecording {
        let id = UUID().uuidString
        let fileName = "\(id).m4a"
        let dest = directoryURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)

        var items = loadAll()
        let entry = WatchPendingRecording(id: id, fileName: fileName, createdAt: Date(), sessionID: sessionID)
        items.append(entry)
        try persist(items)
        return entry
    }

    func fileURL(for recording: WatchPendingRecording) -> URL {
        directoryURL.appendingPathComponent(recording.fileName)
    }

    func remove(id: String) throws {
        var items = loadAll()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        try? FileManager.default.removeItem(at: fileURL(for: item))
        try persist(items)
    }

    private func persist(_ items: [WatchPendingRecording]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: indexURL, options: .atomic)
    }
}
