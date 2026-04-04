import Foundation

/// HTTP client for the future **KB App API** (FastAPI). Telegram bot and this app share the same services on the server.
protocol KnowledgeBaseAPIClientProtocol: Sendable {
    func fetchSessions() async throws -> [KBSession]
    func createSession(title: String) async throws -> KBSession
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

    func createSession(title: String) async throws -> KBSession {
        store.createSession(title: title)
    }
}

/// Placeholder remote client: calls `GET {baseURL}/api/sessions` with `Authorization: Bearer` when configured.
/// Paths and JSON: `docs/KB_APP_API_CONTRACT.md` (OpenAPI subset in `docs/openapi/kb-app-api.yaml`).
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
        try ensureSuccessHTTP(response, data: data)

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

    func createSession(title: String) async throws -> KBSession {
        let url = baseURL.appendingPathComponent("api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable {
            let title: String
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(Body(title: title))

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessHTTP(response, data: data)

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
}

// MARK: - Chat (same transport as sessions)

extension URLSessionKnowledgeBaseAPIClient: ChatAPIClientProtocol {
    func fetchMessages(sessionId: String) async throws -> [KBMessage] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessHTTP(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Page: Codable {
            let items: [KBMessage]?
            let messages: [KBMessage]?
        }

        if let list = try? decoder.decode([KBMessage].self, from: data) {
            return list
        }
        if let page = try? decoder.decode(Page.self, from: data) {
            return page.items ?? page.messages ?? []
        }
        throw KnowledgeBaseAPIError.decodingFailed
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
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable {
            let content: String
            let use_knowledge_base: Bool
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(Body(content: text, use_knowledge_base: useKnowledgeBase))

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessHTTP(response, data: data)

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
        return try await fetchMessages(sessionId: sessionId)
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
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
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable {
            let content: String
            let use_knowledge_base: Bool
        }

        request.httpBody = try JSONEncoder().encode(Body(content: trimmed, use_knowledge_base: useKnowledgeBase))

        let (bytes, response) = try await urlSession.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil)
        }
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
            messages = try await fetchMessages(sessionId: sessionId)
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

    private func streamAssistantByWord(_ full: String) -> AsyncThrowingStream<String, Error> {
        let parts = full.components(separatedBy: " ")
        return AsyncThrowingStream { continuation in
            Task {
                for (index, part) in parts.enumerated() {
                    let chunk = index == 0 ? part : " " + part
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 8_000_000)
                }
                continuation.finish()
            }
        }
    }

    private func streamAssistantChunksFromSSE(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var pending = Data()
                    for try await byte in bytes {
                        pending.append(byte)
                        while let r = pending.range(of: Data([10, 10])) {
                            let eventBytes = pending[..<r.lowerBound]
                            pending = Data(pending[r.upperBound...])
                            let block = String(decoding: eventBytes, as: UTF8.self)
                            guard let payload = SSEventParser.dataPayload(fromSingleEventBlock: block) else { continue }
                            let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }
                            if let jsonData = trimmed.data(using: .utf8),
                               let evt = try? JSONDecoder().decode(ChatSSEEvent.self, from: jsonData) {
                                if let d = evt.delta, !d.isEmpty {
                                    continuation.yield(d)
                                }
                                if evt.done == true {
                                    continuation.finish()
                                    return
                                }
                            } else {
                                continuation.yield(trimmed)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let fileData = try Data(contentsOf: fileURL)
        request.httpBody = Self.multipartAttachmentBody(
            boundary: boundary,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType,
            useKnowledgeBase: useKnowledgeBase
        )

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessHTTP(response, data: data)

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
        return try await fetchMessages(sessionId: sessionId)
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
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

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

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessHTTP(response, data: data)

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
        let fallback = try await fetchMessages(sessionId: sessionId)
        return VoiceRecordingSendResult(messages: fallback, transcription: nil)
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
}

// MARK: - Changed files (KB App API)

extension URLSessionKnowledgeBaseAPIClient: FilesAPIClientProtocol {
    func fetchChangedFiles() async throws -> [KBChangedFile] {
        let url = baseURL.appendingPathComponent("api/files/changes")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessFiles(response, data: data)

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
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        struct Body: Encodable {
            let file_id: String
        }

        request.httpBody = try JSONEncoder().encode(Body(file_id: id))

        let (data, response) = try await urlSession.data(for: request)
        try ensureSuccessFiles(response, data: data)
    }
}

private extension URLSessionKnowledgeBaseAPIClient {
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
