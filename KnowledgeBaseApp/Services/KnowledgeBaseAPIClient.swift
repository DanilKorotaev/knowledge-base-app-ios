import Foundation

/// HTTP client for the future **KB App API** (FastAPI). Telegram bot and this app share the same services on the server.
/// Read-only public link for a chat session (`POST /api/sessions/{id}/share`).
struct SessionShareLink: Equatable, Sendable {
    let shareURL: URL
    let apiURL: URL?
    let expiresAt: Date?
}

protocol KnowledgeBaseAPIClientProtocol: Sendable {
    func fetchSessions() async throws -> [KBSession]
    func fetchArchivedSessions() async throws -> [KBSession]
    func searchSessions(query: String) async throws -> [KBSession]
    func createSession(title: String, useKnowledgeBase: Bool) async throws -> KBSession
    func deleteSession(id: String) async throws
    func archiveSession(id: String) async throws -> KBSession
    func restoreSession(id: String) async throws -> KBSession
    func updateSession(id: String, title: String) async throws -> KBSession
    func createSessionShare(sessionId: String, ttlDays: Int?) async throws -> SessionShareLink
    func revokeSessionShare(sessionId: String) async throws
    func registerDevice(token: String, apnsEnvironment: String, appVersion: String?) async throws
    func unregisterDevice(token: String) async throws
}

enum KnowledgeBaseAPIError: Error, Equatable {
    case missingBaseURL
    case invalidResponse(statusCode: Int, apiMessage: String? = nil)
    case decodingFailed
}

/// In-memory demo sessions when no API base URL is configured (shared `InMemoryKBStore` with `StubChatAPIClient`).
struct StubKnowledgeBaseAPIClient: KnowledgeBaseAPIClientProtocol {
    let store: InMemoryKBStore

    init(store: InMemoryKBStore = InMemoryKBStore()) {
        self.store = store
    }

    func fetchSessions() async throws -> [KBSession] {
        store.sessionsSnapshot()
    }

    func fetchArchivedSessions() async throws -> [KBSession] {
        store.archivedSessionsSnapshot()
    }

    func searchSessions(query: String) async throws -> [KBSession] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.sessionsSnapshot() }
        return store.sessionsSnapshot().filter { session in
            session.title.lowercased().contains(q) || session.id.lowercased().contains(q)
        }
    }

    func createSession(title: String, useKnowledgeBase: Bool = true) async throws -> KBSession {
        store.createSession(title: title, useKnowledgeBase: useKnowledgeBase)
    }

    func deleteSession(id: String) async throws {
        store.deleteSession(id: id)
    }

    func archiveSession(id: String) async throws -> KBSession {
        store.archiveSession(id: id)
    }

    func restoreSession(id: String) async throws -> KBSession {
        store.restoreSession(id: id)
    }

    func updateSession(id: String, title: String) async throws -> KBSession {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: 400, apiMessage: "Title cannot be empty")
        }
        store.updateSessionTitle(id: id, title: trimmed)
        guard let session = store.sessionsSnapshot().first(where: { $0.id == id }) else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: 404, apiMessage: "Session not found")
        }
        return session
    }

    func createSessionShare(sessionId: String, ttlDays: Int? = nil) async throws -> SessionShareLink {
        _ = ttlDays
        guard store.sessionsSnapshot().contains(where: { $0.id == sessionId }) else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: 404, apiMessage: "Session not found")
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        guard let url = URL(string: "https://example.invalid/share/\(token)") else {
            throw KnowledgeBaseAPIError.decodingFailed
        }
        return SessionShareLink(shareURL: url, apiURL: nil, expiresAt: Date().addingTimeInterval(30 * 24 * 3_600))
    }

    func revokeSessionShare(sessionId: String) async throws {
        guard store.sessionsSnapshot().contains(where: { $0.id == sessionId }) else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: 404, apiMessage: "Session not found")
        }
    }

    func registerDevice(token: String, apnsEnvironment: String, appVersion: String?) async throws {}

    func unregisterDevice(token: String) async throws {}
}

/// Remote client via Alamofire (`KBHTTPTransport`): auth headers + request/response logging.
/// Paths and JSON: `docs/KB_APP_API_CONTRACT.md` (OpenAPI subset in `docs/openapi/kb-app-api.yaml`).
final class URLSessionKnowledgeBaseAPIClient: KnowledgeBaseAPIClientProtocol, @unchecked Sendable {
    private let fallbackBaseURL: URL
    /// Shared with Chat / Files / attachment extensions in sibling files.
    let transport: KBHTTPTransport

    /// Live API base — follows account switch when `AppConfiguration` base URL changes.
    var baseURL: URL {
        AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) ?? fallbackBaseURL
    }

    init(
        baseURL: URL,
        authToken: String?,
        urlSession: URLSession = .shared,
        useE2EIntegrationUser: Bool = false
    ) {
        self.fallbackBaseURL = baseURL
        self.transport = KBHTTPTransport(
            authToken: authToken,
            useE2EIntegrationUser: useE2EIntegrationUser,
            urlSession: urlSession
        )
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchSessions() async throws -> [KBSession] {
        var all: [KBSession] = []
        var page = 1
        let perPage = 100
        var total = 0

        while true {
            let batch = try await fetchSessionsPage(page: page, perPage: perPage)
            if page == 1 {
                total = batch.total
            }
            if batch.sessions.isEmpty {
                break
            }
            all.append(contentsOf: batch.sessions)
            if all.count >= total {
                break
            }
            page += 1
        }
        return all
    }

    func searchSessions(query: String) async throws -> [KBSession] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await fetchSessions() }

        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sessions/search"),
            resolvingAgainstBaseURL: false
        ) else {
            throw KnowledgeBaseAPIError.missingBaseURL
        }
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components.url else { throw KnowledgeBaseAPIError.missingBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await performData(request)
        return try decodeSessionList(from: data)
    }

    private struct SessionsListPayload: Codable {
        let items: [KBSession]?
        let sessions: [KBSession]?
        let total: Int?
    }

    private func fetchSessionsPage(page: Int, perPage: Int) async throws -> (sessions: [KBSession], total: Int) {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sessions"),
            resolvingAgainstBaseURL: false
        ) else {
            throw KnowledgeBaseAPIError.missingBaseURL
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        guard let url = components.url else { throw KnowledgeBaseAPIError.missingBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sessions = try? decoder.decode([KBSession].self, from: data) {
            return (sessions, sessions.count)
        }
        let payload = try decoder.decode(SessionsListPayload.self, from: data)
        let sessions = payload.items ?? payload.sessions ?? []
        return (sessions, payload.total ?? sessions.count)
    }

    private func decodeSessionList(from data: Data) throws -> [KBSession] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sessions = try? decoder.decode([KBSession].self, from: data) {
            return sessions
        }
        let payload = try decoder.decode(SessionsListPayload.self, from: data)
        return payload.items ?? payload.sessions ?? []
    }

    func createSession(title: String, useKnowledgeBase: Bool = true) async throws -> KBSession {
        let url = baseURL.appendingPathComponent("api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let title: String
            let useKnowledgeBase: Bool

            enum CodingKeys: String, CodingKey {
                case title
                case useKnowledgeBase = "use_knowledge_base"
            }
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(Body(title: title, useKnowledgeBase: useKnowledgeBase))

        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let session: KBSession?
        }

        if let session = try? decoder.decode(KBSession.self, from: data) {
            return session
        }
        if let env = try? decoder.decode(Envelope.self, from: data), let session = env.session {
            return session
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }

    func deleteSession(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await performData(request)
    }

    func fetchArchivedSessions() async throws -> [KBSession] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent("archived")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw KnowledgeBaseAPIError.missingBaseURL
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        guard let requestURL = components.url else { throw KnowledgeBaseAPIError.missingBaseURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        let data = try await performData(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Page: Codable {
            let sessions: [KBSession]
        }
        if let page = try? decoder.decode(Page.self, from: data) {
            return page.sessions
        }
        if let sessions = try? decoder.decode([KBSession].self, from: data) {
            return sessions
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }

    func archiveSession(id: String) async throws -> KBSession {
        try await postSessionAction(id: id, action: "archive")
    }

    func restoreSession(id: String) async throws -> KBSession {
        try await postSessionAction(id: id, action: "restore")
    }

    private func postSessionAction(id: String, action: String) async throws -> KBSession {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(id)
            .appendingPathComponent(action)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let data = try await performData(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Envelope: Codable {
            let session: KBSession?
        }
        if let env = try? decoder.decode(Envelope.self, from: data), let session = env.session {
            return session
        }
        if let session = try? decoder.decode(KBSession.self, from: data) {
            return session
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }

    func updateSession(id: String, title: String) async throws -> KBSession {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let title: String
        }

        request.httpBody = try JSONEncoder().encode(Body(title: title))

        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let session: KBSession?
        }

        if let env = try? decoder.decode(Envelope.self, from: data), let session = env.session {
            return session
        }
        if let session = try? decoder.decode(KBSession.self, from: data) {
            return session
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }

    func createSessionShare(sessionId: String, ttlDays: Int? = nil) async throws -> SessionShareLink {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("share")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable {
            let ttlDays: Int?
            enum CodingKeys: String, CodingKey {
                case ttlDays = "ttl_days"
            }
        }
        request.httpBody = try JSONEncoder().encode(Body(ttlDays: ttlDays))

        let data = try await performData(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Payload: Decodable {
            let shareURL: String
            let apiURL: String?
            let expiresAt: Date?
            enum CodingKeys: String, CodingKey {
                case shareURL = "share_url"
                case apiURL = "api_url"
                case expiresAt = "expires_at"
            }
        }
        let payload = try decoder.decode(Payload.self, from: data)
        guard let shareURL = URL(string: payload.shareURL) else {
            throw KnowledgeBaseAPIError.decodingFailed
        }
        let apiURL = payload.apiURL.flatMap(URL.init(string:))
        return SessionShareLink(shareURL: shareURL, apiURL: apiURL, expiresAt: payload.expiresAt)
    }

    func revokeSessionShare(sessionId: String) async throws {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("share")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await performData(request)
    }

    func registerDevice(token: String, apnsEnvironment: String, appVersion: String?) async throws {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent("devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let device_token: String
            let platform: String
            let apns_environment: String
            let app_version: String?
        }

        request.httpBody = try JSONEncoder().encode(
            Body(
                device_token: token,
                platform: "ios",
                apns_environment: apnsEnvironment,
                app_version: appVersion
            )
        )
        _ = try await performData(request)
    }

    func unregisterDevice(token: String) async throws {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("devices")
            .appendingPathComponent(encoded)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await performData(request)
    }
}

// MARK: - Changed files (KB App API)

extension URLSessionKnowledgeBaseAPIClient: FilesAPIClientProtocol {
    func fetchChangedFiles(sessionId: String?) async throws -> [KBChangedFile] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/files/changes"),
            resolvingAgainstBaseURL: false
        )
        if let sessionId, !sessionId.isEmpty {
            components?.queryItems = [URLQueryItem(name: "session_id", value: sessionId)]
        }
        guard let url = components?.url else {
            throw FilesAPIError.decodingFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await performFilesData(request)

        let decoder = JSONDecoder()

        struct Page: Codable {
            let items: [KBChangedFile]?
            let files: [KBChangedFile]?
            let changes: [KBChangedFile]?
        }

        if let list = try? decoder.decode([KBChangedFile].self, from: data) {
            return list
        }
        if let page = try? decoder.decode(Page.self, from: data) {
            return page.items ?? page.files ?? page.changes ?? []
        }
        throw FilesAPIError.decodingFailed
    }

    func revertFile(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/files/revert")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let file_id: String
        }

        request.httpBody = try JSONEncoder().encode(Body(file_id: id))

        _ = try await performFilesData(request)
    }

    func createOpenLink(fileId: String) async throws -> KBFileOpenLink {
        let url = baseURL.appendingPathComponent("api/files/open-link")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let file_id: String
        }

        request.httpBody = try JSONEncoder().encode(Body(file_id: fileId))
        let data = try await performFilesData(request)
        do {
            return try JSONDecoder().decode(KBFileOpenLink.self, from: data)
        } catch {
            throw FilesAPIError.decodingFailed
        }
    }
}

// MARK: - Attachment file download (authenticated)

extension URLSessionKnowledgeBaseAPIClient: KBAttachmentLoaderProtocol {
    func absoluteURL(for downloadPath: String) -> URL? {
        if downloadPath.hasPrefix("http://") || downloadPath.hasPrefix("https://") {
            return URL(string: downloadPath)
        }
        var trimmed = downloadPath
        if trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }
        return baseURL.appendingPathComponent(trimmed)
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        guard let url = absoluteURL(for: downloadPath) else {
            throw KnowledgeBaseAPIError.missingBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await performData(request)
    }
}

extension URLSessionKnowledgeBaseAPIClient {
    func performData(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await transport.data(for: request)
        try ensureSuccessHTTP(response, data: data)
        return data
    }

    func performFilesData(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await transport.data(for: request)
        try ensureSuccessFiles(response, data: data)
        return data
    }

    func ensureSuccessHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: data)
            )
        }
    }

    func ensureSuccessFiles(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FilesAPIError.invalidResponse(statusCode: -1, apiMessage: nil)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FilesAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: data)
            )
        }
    }
}
