import Foundation

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
        guard var components = URLComponents(
            url: baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("sessions")
                .appendingPathComponent(sessionId)
                .appendingPathComponent("messages"),
            resolvingAgainstBaseURL: false
        ) else {
            throw KnowledgeBaseAPIError.missingBaseURL
        }
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let beforeMessageId, !beforeMessageId.isEmpty {
            query.append(URLQueryItem(name: "before", value: beforeMessageId))
        }
        components.queryItems = query

        guard let requestURL = components.url else { throw KnowledgeBaseAPIError.missingBaseURL }
        var request = URLRequest(url: requestURL)
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

        struct Envelope: Decodable {
            let messages: [KBMessage]?
            let userMessageAcked: ChatSSEUserMessageAck?

            enum CodingKeys: String, CodingKey {
                case messages
                case userMessageAcked = "user_message_acked"
            }
        }

        var ackEvent: AssistantStreamEvent?
        let messages: [KBMessage]
        if let env = try? decoder.decode(Envelope.self, from: data), let m = env.messages {
            messages = m
            if let ack = env.userMessageAcked {
                ackEvent = .userMessageAcked(
                    messageId: String(ack.messageId),
                    clientMessageId: ack.clientMessageId
                )
            }
        } else if let list = try? decoder.decode([KBMessage].self, from: data) {
            messages = list
        } else {
            messages = try await messagesFromPostResponse(data: data, sessionId: sessionId)
        }

        guard let assistant = messages.last(where: { $0.role == .assistant }) else {
            if let ackEvent {
                return AsyncThrowingStream { continuation in
                    continuation.yield(ackEvent)
                    continuation.finish()
                }
            }
            return AsyncThrowingStream { $0.finish() }
        }
        let wordStream = streamAssistantByWord(assistant.content)
        guard let ackEvent else { return wordStream }
        return AsyncThrowingStream { continuation in
            continuation.yield(ackEvent)
            Task {
                do {
                    for try await event in wordStream {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
                            guard let block = String(bytes: eventBytes, encoding: .utf8) else { continue }
                            guard let payload = SSEventParser.dataPayload(fromSingleEventBlock: block) else { continue }
                            if Self.handleSSEChatPayload(payload, continuation: continuation) {
                                sawDoneEvent = true
                                break
                            }
                        }
                        if sawDoneEvent { break }
                    }
                    if !sawDoneEvent, !pending.isEmpty {
                        if let block = String(bytes: pending, encoding: .utf8),
                           let payload = SSEventParser.dataPayload(fromSingleEventBlock: block),
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
            if let ack = evt.userMessageAcked {
                continuation.yield(
                    .userMessageAcked(
                        messageId: String(ack.messageId),
                        clientMessageId: ack.clientMessageId
                    )
                )
                return false
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

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"content\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(content)\(crlf)".utf8))

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(useKnowledgeBase)\(crlf)".utf8))

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(
            Data("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".utf8)
        )
        data.append(Data("Content-Type: \(mime)\(crlf)\(crlf)".utf8))
        data.append(fileData)
        data.append(Data(crlf.utf8))
        data.append(Data("--\(boundary)--\(crlf)".utf8))
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

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(
            Data("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".utf8)
        )
        data.append(Data("Content-Type: \(mime)\(crlf)\(crlf)".utf8))
        data.append(fileData)
        data.append(Data(crlf.utf8))
        data.append(Data("--\(boundary)--\(crlf)".utf8))
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

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"session_id\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(sessionId)\(crlf)".utf8))

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(useKnowledgeBase)\(crlf)".utf8))

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"transcription_hint\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(transcriptionHint)\(crlf)".utf8))

        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(
            Data("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".utf8)
        )
        data.append(Data("Content-Type: \(mime)\(crlf)\(crlf)".utf8))
        data.append(fileData)
        data.append(Data(crlf.utf8))
        data.append(Data("--\(boundary)--\(crlf)".utf8))
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
        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"use_knowledge_base\"\(crlf)\(crlf)".utf8))
        data.append(Data("\(useKnowledgeBase)\(crlf)".utf8))
        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(
            Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(crlf)".utf8)
        )
        data.append(Data("Content-Type: \(mimeType)\(crlf)\(crlf)".utf8))
        data.append(fileData)
        data.append(Data(crlf.utf8))
        data.append(Data("--\(boundary)--\(crlf)".utf8))
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
            data.append(Data("--\(boundary)\(crlf)".utf8))
            data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".utf8))
            data.append(Data("\(value)\(crlf)".utf8))
        }

        appendField(name: "content", value: draft.text)
        appendField(name: "use_knowledge_base", value: useKnowledgeBase ? "true" : "false")
        if let clientMessageId = draft.clientMessageId, !clientMessageId.isEmpty {
            appendField(name: "client_message_id", value: clientMessageId)
        }

        let transcriptions = draft.voiceClips.map(\.transcriptionSegment)
        if !transcriptions.isEmpty {
            let json = try JSONSerialization.data(withJSONObject: transcriptions)
            guard let transcriptionsJSON = String(bytes: json, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            appendField(name: "audio_transcriptions", value: transcriptionsJSON)
        }

        for attachment in draft.attachments {
            let fileData = try Data(contentsOf: attachment.localURL)
            data.append(Data("--\(boundary)\(crlf)".utf8))
            data.append(
                Data("Content-Disposition: form-data; name=\"files\"; filename=\"\(attachment.filename)\"\(crlf)".utf8)
            )
            data.append(Data("Content-Type: \(attachment.mimeType)\(crlf)\(crlf)".utf8))
            data.append(fileData)
            data.append(Data(crlf.utf8))
        }

        for clip in draft.voiceClips {
            let fileData = try Data(contentsOf: clip.audioURL)
            let filename = clip.audioURL.lastPathComponent
            data.append(Data("--\(boundary)\(crlf)".utf8))
            data.append(
                Data("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\(crlf)".utf8)
            )
            data.append(Data("Content-Type: audio/mp4\(crlf)\(crlf)".utf8))
            data.append(fileData)
            data.append(Data(crlf.utf8))
        }

        data.append(Data("--\(boundary)--\(crlf)".utf8))
        return data
    }

    func sendUIEvent(
        sessionId: String,
        actionId: String,
        componentId: String,
        clientSchemaVersion: Int,
        values: [String: StructuredUIFormValue]? = nil
    ) async throws -> KBUIEventResponse {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("sessions")
            .appendingPathComponent(sessionId)
            .appendingPathComponent("ui-events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let action_id: String
            let component_id: String
            let client_schema_version: Int
            let values: [String: StructuredUIFormValue]?
        }

        request.httpBody = try JSONEncoder().encode(
            Body(
                action_id: actionId,
                component_id: componentId,
                client_schema_version: clientSchemaVersion,
                values: values
            )
        )

        let data = try await performData(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let response = try? decoder.decode(KBUIEventResponse.self, from: data) else {
            throw KnowledgeBaseAPIError.decodingFailed
        }
        return response
    }
}
