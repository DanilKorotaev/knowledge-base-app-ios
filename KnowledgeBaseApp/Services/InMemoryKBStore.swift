import Foundation

/// Shared demo state for stub clients (no backend). Tests can instantiate a fresh store per case.
final class InMemoryKBStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _sessions: [KBSession]
    private var _messages: [String: [KBMessage]]

    init(demoSession: Bool = true) {
        if demoSession {
            _sessions = [
                KBSession(id: "demo-session", title: "Demo session", messageCount: 0, updatedAt: Date())
            ]
        } else {
            _sessions = []
        }
        _messages = [:]
    }

    func sessionsSnapshot() -> [KBSession] {
        lock.lock()
        defer { lock.unlock() }
        return _sessions.map { s in
            let n = _messages[s.id]?.count ?? 0
            return KBSession(id: s.id, title: s.title, messageCount: n, updatedAt: s.updatedAt)
        }
    }

    func messages(for sessionId: String) -> [KBMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _messages[sessionId] ?? []
    }

    func replaceMessages(_ messages: [KBMessage], sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        _messages[sessionId] = messages
    }
}
