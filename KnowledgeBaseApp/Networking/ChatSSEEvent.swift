import Foundation

/// JSON inside an SSE `data:` line for chat streaming (see `docs/KB_APP_API_CONTRACT.md`).
struct ChatSSEEvent: Decodable, Sendable {
    let delta: String?
    let done: Bool?
    let status: String?
    let error: String?
    /// Cursor tool progress (`activity` + `label`) while waiting for first text delta.
    let activity: String?
    let label: String?
}
