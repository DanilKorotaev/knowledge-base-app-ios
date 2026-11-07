import Foundation

struct KBNotification: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var kind: String
    var title: String
    var body: String
    var sourceKey: String?
    var sessionId: Int?
    var messageId: Int?
    var eventId: String?
    var createdAt: String?
    var readAt: String?
    var unread: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, unread
        case sourceKey = "source_key"
        case sessionId = "session_id"
        case messageId = "message_id"
        case eventId = "event_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var systemImageName: String {
        switch kind {
        case "ingress_event":
            return "antenna.radiowaves.left.and.right"
        case "agent_reply":
            return "bubble.left.and.bubble.right"
        case "health_sync":
            return "heart.text.square"
        default:
            return "bell"
        }
    }
}

struct NotificationsListResponse: Codable, Equatable {
    var notifications: [KBNotification]
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
    }
}

protocol NotificationsAPIClientProtocol: Sendable {
    func fetchNotifications(limit: Int) async throws -> NotificationsListResponse
    func fetchUnreadCount() async throws -> Int
    func markRead(id: String) async throws -> Int
    func markAllRead() async throws
}

enum NotificationsAPIError: Error, LocalizedError, Equatable {
    case missingBaseURL
    case invalidResponse(statusCode: Int, apiMessage: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingBaseURL: return "API base URL is not configured"
        case .invalidResponse(let code, let message): return message ?? "HTTP \(code)"
        case .decodingFailed: return "Failed to decode notifications"
        }
    }
}

final class URLSessionNotificationsAPIClient: NotificationsAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: KBHTTPTransport

    init(baseURL: URL, authToken: String?, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.transport = KBHTTPTransport(authToken: authToken, urlSession: urlSession)
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchNotifications(limit: Int = 50) async throws -> NotificationsListResponse {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("api/me/notifications"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = comps?.url else { throw NotificationsAPIError.missingBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(NotificationsListResponse.self, from: data) else {
            throw NotificationsAPIError.decodingFailed
        }
        return decoded
    }

    func fetchUnreadCount() async throws -> Int {
        let url = baseURL.appendingPathComponent("api/me/notifications/unread-count")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        struct Envelope: Decodable { var unread_count: Int }
        guard let decoded = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw NotificationsAPIError.decodingFailed
        }
        return decoded.unread_count
    }

    func markRead(id: String) async throws -> Int {
        let url = baseURL.appendingPathComponent("api/me/notifications/\(id)/read")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        struct Envelope: Decodable { var unread_count: Int }
        return (try? JSONDecoder().decode(Envelope.self, from: data))?.unread_count ?? 0
    }

    func markAllRead() async throws {
        let url = baseURL.appendingPathComponent("api/me/notifications/read-all")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
    }

    private static func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(KBAPIErrorEnvelope.self, from: data))?.error.message
            throw NotificationsAPIError.invalidResponse(
                statusCode: response.statusCode,
                apiMessage: message
            )
        }
    }
}

final class StubNotificationsAPIClient: NotificationsAPIClientProtocol, @unchecked Sendable {
    var notifications: [KBNotification] = []
    var unreadCount: Int = 0

    func fetchNotifications(limit: Int) async throws -> NotificationsListResponse {
        NotificationsListResponse(
            notifications: Array(notifications.prefix(limit)),
            unreadCount: unreadCount
        )
    }

    func fetchUnreadCount() async throws -> Int { unreadCount }

    func markRead(id: String) async throws -> Int {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].unread = false
            notifications[idx].readAt = "read"
            unreadCount = max(0, unreadCount - 1)
        }
        return unreadCount
    }

    func markAllRead() async throws {
        notifications = notifications.map { note in
            var copy = note
            copy.unread = false
            copy.readAt = copy.readAt ?? "read"
            return copy
        }
        unreadCount = 0
    }
}

private struct KBAPIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable { var message: String? }
    var error: ErrorBody
}
