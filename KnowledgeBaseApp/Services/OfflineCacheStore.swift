import Foundation

// MARK: - Protocols

protocol SessionCacheStoreProtocol: Sendable {
    func loadSessions() -> [KBSession]?
    func saveSessions(_ sessions: [KBSession])
    func upsertSession(_ session: KBSession)
    func removeSession(id: String)
    func lastSessionsSyncAt() -> Date?
}

protocol MessageCacheStoreProtocol: Sendable {
    func loadWindow(sessionId: String) -> KBMessagesPage?
    func saveWindow(sessionId: String, page: KBMessagesPage)
    func removeMessages(forSessionId sessionId: String)
    func lastSyncedAt(sessionId: String) -> Date?
}

// MARK: - File-backed implementation

/// Persistent JSON cache for sessions and per-session message windows (offline foundation).
final class FileOfflineCacheStore: SessionCacheStoreProtocol, MessageCacheStoreProtocol, @unchecked Sendable {
    static let shared = FileOfflineCacheStore()

    private struct SessionsCacheFile: Codable {
        var sessions: [KBSession]
        var lastSyncedAt: Date
    }

    private struct MessagesCacheFile: Codable {
        var messages: [KBMessage]
        var total: Int
        var hasMoreOlder: Bool
        var lastSyncedAt: Date
    }

    private let lock = NSLock()
    private let fileManager: FileManager
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseURL = root.appendingPathComponent("KBOfflineCache", isDirectory: true)
        }
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: messagesDirectoryURL, withIntermediateDirectories: true)
    }

    private var sessionsFileURL: URL {
        baseURL.appendingPathComponent("sessions.json")
    }

    private var messagesDirectoryURL: URL {
        baseURL.appendingPathComponent("messages", isDirectory: true)
    }

    private func messagesFileURL(sessionId: String) -> URL {
        let safeName = sessionId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sessionId
        return messagesDirectoryURL.appendingPathComponent("\(safeName).json")
    }

    // MARK: SessionCacheStoreProtocol

    func loadSessions() -> [KBSession]? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: sessionsFileURL),
              let file = try? decoder.decode(SessionsCacheFile.self, from: data) else {
            return nil
        }
        return file.sessions
    }

    func saveSessions(_ sessions: [KBSession]) {
        lock.lock()
        defer { lock.unlock() }
        let file = SessionsCacheFile(sessions: sessions, lastSyncedAt: Date())
        write(file, to: sessionsFileURL)
    }

    func upsertSession(_ session: KBSession) {
        lock.lock()
        defer { lock.unlock() }
        var sessions = (try? readSessionsFile())?.sessions ?? []
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        write(SessionsCacheFile(sessions: sessions, lastSyncedAt: Date()), to: sessionsFileURL)
    }

    func removeSession(id: String) {
        lock.lock()
        defer { lock.unlock() }
        if var file = try? readSessionsFile() {
            file.sessions.removeAll { $0.id == id }
            file.lastSyncedAt = Date()
            write(file, to: sessionsFileURL)
        }
        removeMessagesFileLocked(sessionId: id)
    }

    func lastSessionsSyncAt() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return try? readSessionsFile()?.lastSyncedAt
    }

    // MARK: MessageCacheStoreProtocol

    func loadWindow(sessionId: String) -> KBMessagesPage? {
        lock.lock()
        defer { lock.unlock() }
        let url = messagesFileURL(sessionId: sessionId)
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(MessagesCacheFile.self, from: data) else {
            return nil
        }
        return KBMessagesPage(
            messages: file.messages,
            total: file.total,
            hasMoreOlder: file.hasMoreOlder
        )
    }

    func saveWindow(sessionId: String, page: KBMessagesPage) {
        lock.lock()
        defer { lock.unlock() }
        let file = MessagesCacheFile(
            messages: page.messages,
            total: page.total,
            hasMoreOlder: page.hasMoreOlder,
            lastSyncedAt: Date()
        )
        write(file, to: messagesFileURL(sessionId: sessionId))
    }

    func removeMessages(forSessionId sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        removeMessagesFileLocked(sessionId: sessionId)
    }

    func lastSyncedAt(sessionId: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let url = messagesFileURL(sessionId: sessionId)
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(MessagesCacheFile.self, from: data) else {
            return nil
        }
        return file.lastSyncedAt
    }

    // MARK: - Private helpers

    private func readSessionsFile() throws -> SessionsCacheFile? {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else { return nil }
        let data = try Data(contentsOf: sessionsFileURL)
        return try decoder.decode(SessionsCacheFile.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func removeMessagesFileLocked(sessionId: String) {
        try? fileManager.removeItem(at: messagesFileURL(sessionId: sessionId))
    }
}
