import Foundation

struct CachedAttachmentEntry: Codable, Identifiable, Equatable, Sendable {
    var cacheKey: String
    var fileName: String?
    var mimeType: String?
    var byteSize: Int
    var sessionId: String?
    var messageId: String?
    var lastAccessAt: Date
    var createdAt: Date

    var id: String { cacheKey }
}

struct CachedAttachmentMetadata: Sendable {
    var fileName: String?
    var mimeType: String?
    var sessionId: String?
    var messageId: String?
}

protocol AttachmentDiskCacheProtocol: Sendable {
    func data(forKey key: String) -> Data?
    func fileURL(forKey key: String) -> URL?
    func store(data: Data, key: String, metadata: CachedAttachmentMetadata)
    func touch(key: String)
    func remove(key: String)
    func removeAll()
    func allEntries() -> [CachedAttachmentEntry]
    func totalByteSize() -> Int64
}

/// Disk cache for downloaded attachment bytes with JSON index + LRU eviction.
final class FileAttachmentDiskCache: AttachmentDiskCacheProtocol, @unchecked Sendable {
    static let shared = FileAttachmentDiskCache()

    private struct IndexFile: Codable {
        var entries: [CachedAttachmentEntry]
    }

    private let lock = NSLock()
    private let fileManager: FileManager
    private let baseURL: URL
    private let maxBytes: Int64
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil,
        maxBytes: Int64 = 256 * 1024 * 1024
    ) {
        self.fileManager = fileManager
        self.maxBytes = maxBytes
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseURL = root
                .appendingPathComponent("KBOfflineCache", isDirectory: true)
                .appendingPathComponent("attachments", isDirectory: true)
        }
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: filesDirectoryURL, withIntermediateDirectories: true)
    }

    private var indexFileURL: URL {
        baseURL.appendingPathComponent("index.json")
    }

    private var filesDirectoryURL: URL {
        baseURL.appendingPathComponent("files", isDirectory: true)
    }

    func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        var index = loadIndexLocked()
        guard let entryIndex = index.entries.firstIndex(where: { $0.cacheKey == key }) else {
            return nil
        }
        let fileURL = diskFileURL(forKey: key)
        guard let data = try? Data(contentsOf: fileURL) else {
            index.entries.remove(at: entryIndex)
            saveIndexLocked(index)
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        index.entries[entryIndex].lastAccessAt = Date()
        saveIndexLocked(index)
        return data
    }

    func fileURL(forKey key: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        let index = loadIndexLocked()
        guard index.entries.contains(where: { $0.cacheKey == key }) else {
            return nil
        }
        let url = diskFileURL(forKey: key)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func store(data: Data, key: String, metadata: CachedAttachmentMetadata) {
        lock.lock()
        defer { lock.unlock() }
        var index = loadIndexLocked()
        let fileURL = diskFileURL(forKey: key)
        try? data.write(to: fileURL, options: .atomic)

        let now = Date()
        let entry = CachedAttachmentEntry(
            cacheKey: key,
            fileName: metadata.fileName,
            mimeType: metadata.mimeType,
            byteSize: data.count,
            sessionId: metadata.sessionId,
            messageId: metadata.messageId,
            lastAccessAt: now,
            createdAt: now
        )
        if let existing = index.entries.firstIndex(where: { $0.cacheKey == key }) {
            index.entries[existing] = entry
        } else {
            index.entries.append(entry)
        }
        saveIndexLocked(index)
        enforceSizeLimitLocked(&index)
    }

    func touch(key: String) {
        lock.lock()
        defer { lock.unlock() }
        var index = loadIndexLocked()
        guard let i = index.entries.firstIndex(where: { $0.cacheKey == key }) else { return }
        index.entries[i].lastAccessAt = Date()
        saveIndexLocked(index)
    }

    func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        var index = loadIndexLocked()
        index.entries.removeAll { $0.cacheKey == key }
        saveIndexLocked(index)
        try? fileManager.removeItem(at: diskFileURL(forKey: key))
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        saveIndexLocked(IndexFile(entries: []))
        if let files = try? fileManager.contentsOfDirectory(at: filesDirectoryURL, includingPropertiesForKeys: nil) {
            for url in files {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func allEntries() -> [CachedAttachmentEntry] {
        lock.lock()
        defer { lock.unlock() }
        return loadIndexLocked().entries.sorted { $0.lastAccessAt > $1.lastAccessAt }
    }

    func totalByteSize() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return loadIndexLocked().entries.reduce(0) { $0 + Int64($1.byteSize) }
    }

    // MARK: - Private

    private func diskFileURL(forKey key: String) -> URL {
        let digest = key.data(using: .utf8).map { data in
            data.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
        } ?? key
        return filesDirectoryURL.appendingPathComponent("\(digest).dat")
    }

    private func loadIndexLocked() -> IndexFile {
        guard let data = try? Data(contentsOf: indexFileURL),
              let index = try? decoder.decode(IndexFile.self, from: data) else {
            return IndexFile(entries: [])
        }
        return index
    }

    private func saveIndexLocked(_ index: IndexFile) {
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: indexFileURL, options: .atomic)
    }

    private func enforceSizeLimitLocked(_ index: inout IndexFile) {
        while totalBytesLocked(index) > maxBytes {
            guard let oldestIndex = index.entries.indices.min(by: {
                index.entries[$0].lastAccessAt < index.entries[$1].lastAccessAt
            }) else { break }
            let key = index.entries[oldestIndex].cacheKey
            try? fileManager.removeItem(at: diskFileURL(forKey: key))
            index.entries.remove(at: oldestIndex)
        }
        saveIndexLocked(index)
    }

    private func totalBytesLocked(_ index: IndexFile) -> Int64 {
        index.entries.reduce(0) { $0 + Int64($1.byteSize) }
    }
}

enum AttachmentCacheKey {
    static func normalize(downloadPath: String) -> String {
        var path = downloadPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        return path
    }

    static func metadata(from downloadPath: String, fileName: String? = nil, mimeType: String? = nil) -> CachedAttachmentMetadata {
        let normalized = normalize(downloadPath: downloadPath)
        var sessionId: String?
        var messageId: String?
        let parts = normalized.split(separator: "/").map(String.init)
        if parts.count >= 5,
           parts[0] == "api", parts[1] == "sessions",
           parts[3] == "attachments" {
            sessionId = parts[2]
            messageId = parts[4]
        }
        return CachedAttachmentMetadata(
            fileName: fileName,
            mimeType: mimeType,
            sessionId: sessionId,
            messageId: messageId
        )
    }
}

enum CacheByteFormatting {
    static func string(for byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}
