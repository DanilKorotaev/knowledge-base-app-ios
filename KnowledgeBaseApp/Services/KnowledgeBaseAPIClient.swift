import Foundation

/// HTTP client for the future **KB App API** (FastAPI). Telegram bot and this app share the same services on the server.
protocol KnowledgeBaseAPIClientProtocol: Sendable {
    func fetchSessions() async throws -> [KBSession]
}

enum KnowledgeBaseAPIError: Error, Equatable {
    case missingBaseURL
    case invalidResponse(statusCode: Int)
    case decodingFailed
}

/// Returns an empty list until the real backend is wired; use for UI previews and offline-first flows.
struct StubKnowledgeBaseAPIClient: KnowledgeBaseAPIClientProtocol {
    func fetchSessions() async throws -> [KBSession] {
        []
    }
}

/// Placeholder remote client: calls `GET {baseURL}/api/sessions` with `Authorization: Bearer` when configured.
/// Adjust paths to match the final KB App API contract (see knowledge base doc «Архитектура и бэкенд API»).
final class URLSessionKnowledgeBaseAPIClient: KnowledgeBaseAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let authToken: String?
    private let urlSession: URLSession

    init(baseURL: URL, authToken: String?, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.urlSession = urlSession
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchSessions() async throws -> [KBSession] {
        let url = baseURL.appendingPathComponent("api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: -1)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Page: Codable {
            let items: [KBSession]?
            let sessions: [KBSession]?
        }

        if let sessions = try? decoder.decode([KBSession].self, from: data) {
            return sessions
        }
        if let page = try? decoder.decode(Page.self, from: data) {
            return page.items ?? page.sessions ?? []
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }
}
