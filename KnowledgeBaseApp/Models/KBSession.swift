import Foundation

/// Mirrors a knowledge-base chat session from the shared PostgreSQL store (future: KB App API).
struct KBSession: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Client-only draft until the first successful `POST /api/sessions` on send.
    static let localDraftIDPrefix = "draft:"

    let id: String
    let title: String
    let messageCount: Int
    let updatedAt: Date?
    let useKnowledgeBase: Bool

    /// True when the session exists only on device and must be created before any chat API call.
    var isLocalDraft: Bool {
        id.hasPrefix(Self.localDraftIDPrefix)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case messageCount = "message_count"
        case updatedAt = "updated_at"
        case useKnowledgeBase = "use_knowledge_base"
    }

    init(
        id: String,
        title: String,
        messageCount: Int,
        updatedAt: Date?,
        useKnowledgeBase: Bool = true
    ) {
        self.id = id
        self.title = title
        self.messageCount = messageCount
        self.updatedAt = updatedAt
        self.useKnowledgeBase = useKnowledgeBase
    }

    /// Empty chat shell for toolbar **+**. Listed only once composer has unsent content.
    static func makeLocalDraft(
        useKnowledgeBase: Bool = true,
        title: String = ""
    ) -> KBSession {
        KBSession(
            id: localDraftIDPrefix + UUID().uuidString,
            title: title,
            messageCount: 0,
            updatedAt: nil,
            useKnowledgeBase: useKnowledgeBase
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messageCount = try container.decode(Int.self, forKey: .messageCount)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        useKnowledgeBase = try container.decodeIfPresent(Bool.self, forKey: .useKnowledgeBase) ?? true
    }
}
