import Foundation

enum MessageRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
    case system
}

struct KBMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let role: MessageRole
    let content: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
    }
}
