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
            _messages = ["demo-session": Self.richDemoMessages()]
        } else {
            _sessions = []
            _messages = [:]
        }
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

    /// Appends a new session (stub / offline).
    @discardableResult
    func createSession(title: String) -> KBSession {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "New session" : trimmed
        lock.lock()
        defer { lock.unlock() }
        let id = "local-\(UUID().uuidString)"
        let session = KBSession(id: id, title: name, messageCount: 0, updatedAt: Date())
        _sessions.insert(session, at: 0)
        return session
    }

    private static func richDemoMessages() -> [KBMessage] {
        [
            KBMessage(
                id: "demo-photo",
                role: .user,
                content: "Photo from the meeting",
                createdAt: Date().addingTimeInterval(-300),
                attachments: [
                    KBAttachment(
                        id: "att-photo-1",
                        fileType: "photo",
                        fileName: "whiteboard.jpg",
                        fileSize: 2048,
                        mimeType: "image/jpeg",
                        downloadURL: "demo-photo",
                        transcription: nil
                    )
                ],
                contentFormat: .plain
            ),
            KBMessage(
                id: "demo-voice",
                role: .user,
                content: "🎤 Voice",
                createdAt: Date().addingTimeInterval(-240),
                attachments: [
                    KBAttachment(
                        id: "att-voice-1",
                        fileType: "voice",
                        fileName: "voice.m4a",
                        fileSize: 4096,
                        mimeType: "audio/mp4",
                        downloadURL: "demo-voice",
                        transcription: "Add a meeting tomorrow at 10"
                    )
                ],
                contentFormat: .plain,
                transcription: "Add a meeting tomorrow at 10"
            ),
            KBMessage(
                id: "demo-md",
                role: .assistant,
                content: "**Summary**\n\n- First point\n- Second point\n\nSee `docs/plan.md` for details.",
                createdAt: Date().addingTimeInterval(-120),
                contentFormat: .markdown
            ),
            KBMessage(
                id: "demo-html",
                role: .assistant,
                content: "<b>HTML reply</b> with <i>emphasis</i> and a <a href=\"https://example.com\">link</a>.",
                createdAt: Date(),
                contentFormat: .html
            ),
        ]
    }
}
