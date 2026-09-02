import Foundation

enum ShareAPIError: Error, Equatable {
    case missingConfiguration
    case invalidResponse(statusCode: Int)
    case decodingFailed
}

/// Minimal URLSession client for Share Extension (sessions + compose send). Avoids Alamofire / main-app logging stack.
final class ShareAPIClient: @unchecked Sendable {
    private let baseURL: URL
    private let authToken: String?
    private let urlSession: URLSession

    init(baseURL: URL, authToken: String?, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.urlSession = urlSession
    }

    convenience init?() {
        guard let base = ShareConfiguration.apiBaseURL() else { return nil }
        self.init(baseURL: base, authToken: ShareConfiguration.authToken())
    }

    func fetchSessions() async throws -> [KBSession] {
        var all: [KBSession] = []
        var page = 1
        let perPage = 100
        var total = Int.max

        while all.count < total {
            let batch = try await fetchSessionsPage(page: page, perPage: perPage)
            if page == 1 {
                total = batch.total
            }
            if batch.sessions.isEmpty { break }
            all.append(contentsOf: batch.sessions)
            page += 1
        }
        return all
    }

    func createSession(title: String, useKnowledgeBase: Bool) async throws -> KBSession {
        let url = baseURL.appendingPathComponent("api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)

        struct Body: Encodable {
            let title: String
            let use_knowledge_base: Bool
        }
        request.httpBody = try JSONEncoder().encode(Body(title: title, use_knowledge_base: useKnowledgeBase))

        let data = try await perform(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let session = try? decoder.decode(KBSession.self, from: data) {
            return session
        }
        struct Envelope: Codable { let session: KBSession? }
        if let env = try? decoder.decode(Envelope.self, from: data), let session = env.session {
            return session
        }
        throw ShareAPIError.decodingFailed
    }

    /// Sends compose payload and waits for completion (JSON or drained SSE).
    func sendComposed(sessionId: String, draft: ChatComposerDraft, useKnowledgeBase: Bool) async throws {
        guard draft.canSend else { return }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
            .appendingPathComponent("compose")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        applyAuth(to: &request)

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream;q=0.8", forHTTPHeaderField: "Accept")
        request.httpBody = try multipartComposeBody(boundary: boundary, draft: draft, useKnowledgeBase: useKnowledgeBase)

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareAPIError.invalidResponse(statusCode: -1)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ShareAPIError.invalidResponse(statusCode: http.statusCode)
        }
    }

    // MARK: - Private

    private func fetchSessionsPage(page: Int, perPage: Int) async throws -> (sessions: [KBSession], total: Int) {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sessions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
        ]
        guard let url = components.url else { throw ShareAPIError.missingConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(to: &request)
        let data = try await perform(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sessions = try? decoder.decode([KBSession].self, from: data) {
            return (sessions, sessions.count)
        }
        struct Payload: Codable {
            let items: [KBSession]?
            let sessions: [KBSession]?
            let total: Int?
        }
        let payload = try decoder.decode(Payload.self, from: data)
        let sessions = payload.items ?? payload.sessions ?? []
        return (sessions, payload.total ?? sessions.count)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareAPIError.invalidResponse(statusCode: -1)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ShareAPIError.invalidResponse(statusCode: http.statusCode)
        }
        return data
    }

    private func applyAuth(to request: inout URLRequest) {
        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func multipartComposeBody(
        boundary: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) throws -> Data {
        var data = Data()
        let crlf = "\r\n"

        func appendField(name: String, value: String) {
            data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!)
            data.append("\(value)\(crlf)".data(using: .utf8)!)
        }

        appendField(name: "content", value: draft.text)
        appendField(name: "use_knowledge_base", value: useKnowledgeBase ? "true" : "false")

        for attachment in draft.attachments {
            let fileData = try Data(contentsOf: attachment.localURL)
            data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            data.append(
                "Content-Disposition: form-data; name=\"files\"; filename=\"\(attachment.filename)\"\(crlf)".data(using: .utf8)!
            )
            data.append("Content-Type: \(attachment.mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
            data.append(fileData)
            data.append(crlf.data(using: .utf8)!)
        }

        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }
}
