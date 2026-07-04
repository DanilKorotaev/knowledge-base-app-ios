import Foundation

/// HTTP client for the future **KB App API** (FastAPI). Telegram bot and this app share the same services on the server.
protocol KnowledgeBaseAPIClientProtocol: Sendable {
    func fetchSessions() async throws -> [KBSession]
    func searchSessions(query: String) async throws -> [KBSession]
    func createSession(title: String, useKnowledgeBase: Bool) async throws -> KBSession
    func deleteSession(id: String) async throws
    func updateSession(id: String, title: String) async throws -> KBSession
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

    func registerDevice(token: String, apnsEnvironment: String, appVersion: String?) async throws {}

    func unregisterDevice(token: String) async throws {}
}

/// Remote client via Alamofire (`KBHTTPTransport`): auth headers + request/response logging.
/// Paths and JSON: `docs/KB_APP_API_CONTRACT.md` (OpenAPI subset in `docs/openapi/kb-app-api.yaml`).
final class URLSessionKnowledgeBaseAPIClient: KnowledgeBaseAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: KBHTTPTransport

    init(
        baseURL: URL,
        authToken: String?,
        urlSession: URLSession = .shared,
        useE2EIntegrationUser: Bool = false
    ) {
        self.baseURL = baseURL
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

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sessions/search"),
            resolvingAgainstBaseURL: false
        )!
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
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sessions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
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

// MARK: - Chat (same transport as sessions)

extension URLSessionKnowledgeBaseAPIClient: ChatAPIClientProtocol {
    /// Cursor + KB sync can exceed the default 60s before the first SSE byte.
    private static let sseRequestTimeout: TimeInterval = 600

    private static func applySSETimeout(to request: inout URLRequest) {
        request.timeoutInterval = sseRequestTimeout
    }

    func fetchMessagesPage(
        sessionId: String,
        limit: Int,
        beforeMessageId: String?
    ) async throws -> KBMessagesPage {
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("sessions")
                .appendingPathComponent(sessionId)
                .appendingPathComponent("messages"),
            resolvingAgainstBaseURL: false
        )!
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let beforeMessageId, !beforeMessageId.isEmpty {
            query.append(URLQueryItem(name: "before", value: beforeMessageId))
        }
        components.queryItems = query

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let page = try? decoder.decode(KBMessagesPage.self, from: data) {
            return clampMessagesPage(page, limit: limit)
        }

        struct LegacyEnvelope: Codable {
            let messages: [KBMessage]?
            let items: [KBMessage]?
            let total: Int?
            let hasMoreOlder: Bool?

            enum CodingKeys: String, CodingKey {
                case messages
                case items
                case total
                case hasMoreOlder = "has_more_older"
            }
        }
        if let legacy = try? decoder.decode(LegacyEnvelope.self, from: data) {
            let list = legacy.messages ?? legacy.items ?? []
            let page = KBMessagesPage(
                messages: list,
                total: legacy.total ?? list.count,
                hasMoreOlder: legacy.hasMoreOlder ?? (list.count > limit)
            )
            return clampMessagesPage(page, limit: limit)
        }
        if let list = try? decoder.decode([KBMessage].self, from: data) {
            let page = KBMessagesPage(
                messages: list,
                total: list.count,
                hasMoreOlder: list.count > limit
            )
            return clampMessagesPage(page, limit: limit)
        }
        throw KnowledgeBaseAPIError.decodingFailed
    }

    private func clampMessagesPage(_ page: KBMessagesPage, limit: Int) -> KBMessagesPage {
        guard page.messages.count > limit else { return page }
        let window = Array(page.messages.suffix(limit))
        return KBMessagesPage(
            messages: window,
            total: page.total,
            hasMoreOlder: true
        )
    }

    private func messagesFromPostResponse(data: Data, sessionId: String) async throws -> [KBMessage] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Envelope: Codable {
            let messages: [KBMessage]?
        }
        if let env = try? decoder.decode(Envelope.self, from: data), let messages = env.messages {
            return messages
        }
        if let list = try? decoder.decode([KBMessage].self, from: data) {
            return list
        }
        return try await fetchMessagesPage(sessionId: sessionId, limit: 100, beforeMessageId: nil).messages
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let content: String
            let use_knowledge_base: Bool
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(Body(content: text, use_knowledge_base: useKnowledgeBase))

        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
        }

        if let env = try? decoder.decode(Envelope.self, from: data), let messages = env.messages {
            return messages
        }
        if let list = try? decoder.decode([KBMessage].self, from: data) {
            return list
        }
        return try await messagesFromPostResponse(data: data, sessionId: sessionId)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json;q=0.9", forHTTPHeaderField: "Accept")

        struct Body: Encodable {
            let content: String
            let use_knowledge_base: Bool
        }

        request.httpBody = try JSONEncoder().encode(Body(content: trimmed, use_knowledge_base: useKnowledgeBase))
        Self.applySSETimeout(to: &request)

        let (bytes, http) = try await transport.bytes(for: request)
        guard (200 ... 299).contains(http.statusCode) else {
            let errData = try await collectAsyncBytes(bytes)
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: errData)
            )
        }

        let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if mime.contains("text/event-stream") {
            return streamAssistantChunksFromSSE(bytes: bytes)
        }

        let data = try await collectAsyncBytes(bytes)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
        }

        let messages: [KBMessage]
        if let env = try? decoder.decode(Envelope.self, from: data), let m = env.messages {
            messages = m
        } else if let list = try? decoder.decode([KBMessage].self, from: data) {
            messages = list
        } else {
            messages = try await messagesFromPostResponse(data: data, sessionId: sessionId)
        }

        guard let assistant = messages.last(where: { $0.role == .assistant }) else {
            return AsyncThrowingStream { $0.finish() }
        }
        return streamAssistantByWord(assistant.content)
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
            .appendingPathComponent("voice")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json;q=0.9", forHTTPHeaderField: "Accept")

        let fileData = try Data(contentsOf: audioFileURL)
        request.httpBody = Self.multipartVoiceMessageBody(
            boundary: boundary,
            content: trimmed,
            useKnowledgeBase: useKnowledgeBase,
            fileData: fileData,
            filename: audioFileURL.lastPathComponent
        )
        Self.applySSETimeout(to: &request)

        let (bytes, http) = try await transport.bytes(for: request)
        guard (200 ... 299).contains(http.statusCode) else {
            let errData = try await collectAsyncBytes(bytes)
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: errData)
            )
        }

        let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if mime.contains("text/event-stream") {
            return streamAssistantChunksFromSSE(bytes: bytes)
        }

        let data = try await collectAsyncBytes(bytes)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
        }

        let messages: [KBMessage]
        if let env = try? decoder.decode(Envelope.self, from: data), let m = env.messages {
            messages = m
        } else if let list = try? decoder.decode([KBMessage].self, from: data) {
            messages = list
        } else {
            messages = try await messagesFromPostResponse(data: data, sessionId: sessionId)
        }

        guard let assistant = messages.last(where: { $0.role == .assistant }) else {
            return AsyncThrowingStream { $0.finish() }
        }
        return streamAssistantByWord(assistant.content)
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        guard draft.canSend else {
            return AsyncThrowingStream { $0.finish() }
        }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
            .appendingPathComponent("compose")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json;q=0.9", forHTTPHeaderField: "Accept")

        request.httpBody = try Self.multipartComposeBody(
            boundary: boundary,
            draft: draft,
            useKnowledgeBase: useKnowledgeBase
        )
        Self.applySSETimeout(to: &request)

        let (bytes, http) = try await transport.bytes(for: request)
        guard (200 ... 299).contains(http.statusCode) else {
            let errData = try await collectAsyncBytes(bytes)
            throw KnowledgeBaseAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: errData)
            )
        }

        let mime = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if mime.contains("text/event-stream") {
            return streamAssistantChunksFromSSE(bytes: bytes)
        }

        let data = try await collectAsyncBytes(bytes)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
        }

        let messages: [KBMessage]
        if let env = try? decoder.decode(Envelope.self, from: data), let m = env.messages {
            messages = m
        } else if let list = try? decoder.decode([KBMessage].self, from: data) {
            messages = list
        } else {
            messages = try await messagesFromPostResponse(data: data, sessionId: sessionId)
        }

        guard let assistant = messages.last(where: { $0.role == .assistant }) else {
            return AsyncThrowingStream { $0.finish() }
        }
        return streamAssistantByWord(assistant.content)
    }

    private func collectAsyncBytes(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private func streamAssistantByWord(_ full: String) -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        let parts = full.components(separatedBy: " ")
        return AsyncThrowingStream { continuation in
            Task {
                for (index, part) in parts.enumerated() {
                    let chunk = index == 0 ? part : " " + part
                    continuation.yield(.delta(chunk))
                    try? await Task.sleep(nanoseconds: 8_000_000)
                }
                continuation.finish()
            }
        }
    }

    /// Разбор SSE по границам `\n\n` после нормализации `\r\n` → `\n` (иначе `\r\n\r\n` не даёт пары LF-LF в сырых байтах).
    /// `AsyncBytes.lines` здесь не подходит: пустые строки между событиями часто опускаются, и несколько `data:` сливаются в один блок.
    private func streamAssistantChunksFromSSE(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var pending = Data()
                    var sawDoneEvent = false
                    for try await byte in bytes {
                        if byte == 10, pending.last == 13 {
                            pending[pending.count - 1] = 10
                        } else {
                            pending.append(byte)
                        }
                        while let r = pending.range(of: Data([10, 10])) {
                            let eventBytes = pending[..<r.lowerBound]
                            pending = Data(pending[r.upperBound...])
                            let block = String(decoding: eventBytes, as: UTF8.self)
                            guard let payload = SSEventParser.dataPayload(fromSingleEventBlock: block) else { continue }
                            if Self.handleSSEChatPayload(payload, continuation: continuation) {
                                sawDoneEvent = true
                                break
                            }
                        }
                        if sawDoneEvent { break }
                    }
                    if !sawDoneEvent, !pending.isEmpty {
                        let block = String(decoding: pending, as: UTF8.self)
                        if let payload = SSEventParser.dataPayload(fromSingleEventBlock: block),
                           Self.handleSSEChatPayload(payload, continuation: continuation) {
                            sawDoneEvent = true
                        }
                    }
                    if !sawDoneEvent {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// - Returns: `true` if the stream ended with `done` (continuation already finished).
    private static func handleSSEChatPayload(
        _ payload: String,
        continuation: AsyncThrowingStream<AssistantStreamEvent, Error>.Continuation
    ) -> Bool {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let jsonData = trimmed.data(using: .utf8),
           let evt = try? JSONDecoder().decode(ChatSSEEvent.self, from: jsonData) {
            if let err = evt.error, !err.isEmpty {
                continuation.finish(throwing: KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: err))
                return true
            }
            if evt.status != nil {
                return false
            }
            if let activity = evt.activity, !activity.isEmpty,
               let label = evt.label, !label.isEmpty {
                continuation.yield(.activity(label: label))
                return false
            }
            if let d = evt.delta, !d.isEmpty {
                continuation.yield(.delta(d))
            }
            if evt.done == true {
                continuation.finish()
                return true
            }
            return false
        }
        continuation.yield(.delta(trimmed))
        return false
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("attachments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        request.httpBody = Self.multipartAttachmentBody(
            boundary: boundary,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType,
            useKnowledgeBase: useKnowledgeBase
        )

        let data = try await performData(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
        }

        if let env = try? decoder.decode(Envelope.self, from: data), let messages = env.messages {
            return messages
        }
        if let list = try? decoder.decode([KBMessage].self, from: data) {
            return list
        }
        return try await messagesFromPostResponse(data: data, sessionId: sessionId)
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("query")
            .appendingPathComponent("voice")
            .appendingPathComponent("transcribe")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        request.httpBody = Self.multipartTranscribeBody(
            boundary: boundary,
            fileData: fileData,
            filename: filename
        )

        let data = try await performData(request)

        struct Envelope: Codable {
            let transcription: String?
        }

        let decoder = JSONDecoder()
        if let env = try? decoder.decode(Envelope.self, from: data),
           let text = env.transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        throw KnowledgeBaseAPIError.invalidResponse(
            statusCode: 0,
            apiMessage: "Empty transcription in response"
        )
    }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("query")
            .appendingPathComponent("voice")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        request.httpBody = Self.multipartVoiceQueryBody(
            boundary: boundary,
            sessionId: sessionId,
            useKnowledgeBase: useKnowledgeBase,
            transcriptionHint: transcriptionHint,
            fileData: fileData,
            filename: filename
        )

        let data = try await performData(request)

        return try await decodeVoiceRecordingResponse(data: data, sessionId: sessionId)
    }

    private func decodeVoiceRecordingResponse(data: Data, sessionId: String) async throws -> VoiceRecordingSendResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Envelope: Codable {
            let messages: [KBMessage]?
            let transcription: String?
        }

        if let env = try? decoder.decode(Envelope.self, from: data), let messages = env.messages {
            return VoiceRecordingSendResult(messages: messages, transcription: env.transcription)
        }
        if let list = try? decoder.decode([KBMessage].self, from: data) {
            return VoiceRecordingSendResult(messages: list, transcription: nil)
        }
        let fallback = try await messagesFromPostResponse(data: data, sessionId: sessionId)
        return VoiceRecordingSendResult(messages: fallback, transcription: nil)
    }

    private static func multipartVoiceMessageBody(
        boundary: String,
        content: String,
        useKnowledgeBase: Bool,
        fileData: Data,
        filename: String
    ) -> Data {
        var data = Data()
        let crlf = "\r\n"
        let mime = "audio/mp4"

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"content\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(content)\(crlf)".data(using: .utf8)!)

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(useKnowledgeBase)\(crlf)".data(using: .utf8)!)

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!
        )
        data.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
        data.append(fileData)
        data.append(crlf.data(using: .utf8)!)
        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }

    private static func multipartTranscribeBody(
        boundary: String,
        fileData: Data,
        filename: String
    ) -> Data {
        var data = Data()
        let crlf = "\r\n"
        let mime = "audio/mp4"

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!
        )
        data.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
        data.append(fileData)
        data.append(crlf.data(using: .utf8)!)
        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }

    private static func multipartVoiceQueryBody(
        boundary: String,
        sessionId: String,
        useKnowledgeBase: Bool,
        transcriptionHint: String,
        fileData: Data,
        filename: String
    ) -> Data {
        var data = Data()
        let crlf = "\r\n"
        let mime = "audio/mp4"

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"session_id\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(sessionId)\(crlf)".data(using: .utf8)!)

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(useKnowledgeBase)\(crlf)".data(using: .utf8)!)

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"transcription_hint\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(transcriptionHint)\(crlf)".data(using: .utf8)!)

        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!
        )
        data.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
        data.append(fileData)
        data.append(crlf.data(using: .utf8)!)
        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }

    private static func multipartAttachmentBody(
        boundary: String,
        fileData: Data,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) -> Data {
        var data = Data()
        let crlf = "\r\n"
        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".data(using: .utf8)!)
        data.append("\(useKnowledgeBase)\(crlf)".data(using: .utf8)!)
        data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        data.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!
        )
        data.append("Content-Type: \(mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
        data.append(fileData)
        data.append(crlf.data(using: .utf8)!)
        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }

    private static func multipartComposeBody(
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

        let transcriptions = draft.voiceClips.map(\.transcriptionSegment)
        if !transcriptions.isEmpty {
            let json = try JSONSerialization.data(withJSONObject: transcriptions)
            appendField(name: "audio_transcriptions", value: String(decoding: json, as: UTF8.self))
        }

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

        for clip in draft.voiceClips {
            let fileData = try Data(contentsOf: clip.audioURL)
            let filename = clip.audioURL.lastPathComponent
            data.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            data.append(
                "Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!
            )
            data.append("Content-Type: audio/mp4\(crlf)\(crlf)".data(using: .utf8)!)
            data.append(fileData)
            data.append(crlf.data(using: .utf8)!)
        }

        data.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return data
    }
}

// MARK: - Changed files (KB App API)

extension URLSessionKnowledgeBaseAPIClient: FilesAPIClientProtocol {
    func fetchChangedFiles() async throws -> [KBChangedFile] {
        let url = baseURL.appendingPathComponent("api/files/changes")
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

    func createShareLink(fileId: String) async throws -> URL {
        let url = baseURL.appendingPathComponent("api/files/share-link")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let file_id: String
        }

        struct ResponseBody: Decodable {
            let url: String
        }

        request.httpBody = try JSONEncoder().encode(Body(file_id: fileId))
        let data = try await performFilesData(request)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let link = URL(string: decoded.url) else {
            throw FilesAPIError.decodingFailed
        }
        return link
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

private extension URLSessionKnowledgeBaseAPIClient {
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
