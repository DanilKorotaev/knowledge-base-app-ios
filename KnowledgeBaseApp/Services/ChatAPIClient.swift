import Foundation

/// Messages and text send — separate surface from session list (`KnowledgeBaseAPIClientProtocol`).
protocol ChatAPIClientProtocol: Sendable {
    func fetchMessages(sessionId: String) async throws -> [KBMessage]
    /// Returns the full thread after appending user + assistant messages (stub) or server response (HTTP).
    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage]
    /// Photo or file attachment; real API will run Whisper / file pipeline.
    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage]
}

struct StubChatAPIClient: ChatAPIClientProtocol {
    let store: InMemoryKBStore

    init(store: InMemoryKBStore) {
        self.store = store
    }

    func fetchMessages(sessionId: String) async throws -> [KBMessage] {
        store.messages(for: sessionId)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return store.messages(for: sessionId)
        }

        var list = store.messages(for: sessionId)
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: trimmed,
            createdAt: Date()
        )
        list.append(user)

        let kbNote = useKnowledgeBase ? "with KB" : "empty chat"
        let replyText = "Stub reply (\(kbNote)): \(trimmed.prefix(120))"
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: replyText,
            createdAt: Date()
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        return list
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        var list = store.messages(for: sessionId)
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: "📎 \(filename) (\(size) bytes)",
            createdAt: Date()
        )
        list.append(user)

        let kb = useKnowledgeBase ? "with KB" : "empty chat"
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "Stub attachment (\(kb)): would upload \(filename) (\(mimeType)) to KB App API.",
            createdAt: Date()
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        return list
    }
}
