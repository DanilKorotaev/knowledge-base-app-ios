import Foundation

/// Mirrors a knowledge-base chat session from the shared PostgreSQL store (future: KB App API).
struct KBSession: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let title: String
    let messageCount: Int
    let updatedAt: Date?
    let useKnowledgeBase: Bool

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messageCount = try container.decode(Int.self, forKey: .messageCount)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        useKnowledgeBase = try container.decodeIfPresent(Bool.self, forKey: .useKnowledgeBase) ?? true
    }
}
