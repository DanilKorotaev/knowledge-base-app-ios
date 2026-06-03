import Foundation

/// Page from `GET /api/sessions/{id}/messages?limit=&before=`.
struct KBMessagesPage: Codable, Sendable, Equatable {
    let messages: [KBMessage]
    let total: Int
    let hasMoreOlder: Bool

    enum CodingKeys: String, CodingKey {
        case messages
        case total
        case hasMoreOlder = "has_more_older"
    }
}
