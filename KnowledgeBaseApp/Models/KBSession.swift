import Foundation

/// Mirrors a knowledge-base chat session from the shared PostgreSQL store (future: KB App API).
struct KBSession: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let messageCount: Int
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case messageCount = "message_count"
        case updatedAt = "updated_at"
    }
}
