import Foundation

/// JSON inside an SSE `data:` line for chat streaming (see `docs/KB_APP_API_CONTRACT.md`).
struct ChatSSEEvent: Decodable, Sendable {
    let delta: String?
    let done: Bool?
}
