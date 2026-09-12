import Foundation

/// Nested payload for early user-message ack (compose/messages SSE).
struct ChatSSEUserMessageAck: Decodable, Sendable, Equatable {
    let messageId: Int
    let clientMessageId: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case clientMessageId = "client_message_id"
    }
}

/// JSON inside an SSE `data:` line for chat streaming (see `docs/KB_APP_API_CONTRACT.md`).
struct ChatSSEEvent: Decodable, Sendable {
    let delta: String?
    let done: Bool?
    let status: String?
    let error: String?
    /// Cursor tool progress (`activity` + `label`) while waiting for first text delta.
    let activity: String?
    let label: String?
    let userMessageAcked: ChatSSEUserMessageAck?

    enum CodingKeys: String, CodingKey {
        case delta
        case done
        case status
        case error
        case activity
        case label
        case userMessageAcked = "user_message_acked"
    }
}
