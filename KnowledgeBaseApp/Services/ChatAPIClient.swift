import Foundation

/// Messages and text send — separate surface from session list (`KnowledgeBaseAPIClientProtocol`).
protocol ChatAPIClientProtocol: Sendable {
    func fetchMessagesPage(
        sessionId: String,
        limit: Int,
        beforeMessageId: String?
    ) async throws -> KBMessagesPage
    /// Returns the full thread after appending user + assistant messages (stub) or server response (HTTP).
    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage]
    /// Photo or file attachment; real API will run Whisper / file pipeline.
    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage]

    /// Whisper only — `POST /api/query/voice/transcribe` (no session / no assistant reply).
    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String

    /// Voice note: multipart to `POST /api/query/voice` (KB App API); optional `transcription` from Whisper.
    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult

    /// Assistant reply as token chunks. Implementations add the user message before the first yield (stub); HTTP runs `POST …/messages` first, then yields assistant text (until SSE exists).
    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error>

    /// Text + voice file: `POST …/messages/voice` (multipart + SSE). Saves audio and transcription on the server.
    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error>

    /// Text + multiple files/voice clips: `POST …/messages/compose` (multipart + SSE).
    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error>
}

struct StubChatAPIClient: ChatAPIClientProtocol {
    let store: InMemoryKBStore
    /// Test hook: delay before the first stream chunk (exercises `.waiting` UI).
    var streamInitialDelayNanoseconds: UInt64 = 0

    init(store: InMemoryKBStore) {
        self.store = store
    }

    func fetchMessagesPage(
        sessionId: String,
        limit: Int,
        beforeMessageId: String?
    ) async throws -> KBMessagesPage {
        var all = store.messages(for: sessionId)
        if let before = beforeMessageId,
           let index = all.firstIndex(where: { $0.id == before }) {
            all = Array(all.prefix(index))
        }
        let slice = Array(all.suffix(limit))
        let hasMore = all.count > slice.count
        return KBMessagesPage(messages: slice, total: store.messages(for: sessionId).count, hasMoreOlder: hasMore)
    }

    func sendTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> [KBMessage] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return store.messages(for: sessionId)
        }

        var list = store.messages(for: sessionId)
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: trimmed,
            createdAt: Date()
        )
        list.append(user)

        let kbNote = useKnowledgeBase ? "with KB" : "empty chat"
        let replyText = "Stub reply (\(kbNote)): \(trimmed.prefix(120))"
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: replyText,
            createdAt: Date()
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        return list
    }

    func sendAttachment(
        sessionId: String,
        fileURL: URL,
        filename: String,
        mimeType: String,
        useKnowledgeBase: Bool
    ) async throws -> [KBMessage] {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        var list = store.messages(for: sessionId)
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: "📎 \(filename) (\(size) bytes)",
            createdAt: Date()
        )
        list.append(user)

        let kb = useKnowledgeBase ? "with KB" : "empty chat"
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "Stub attachment (\(kb)): would upload \(filename) (\(mimeType)) to KB App API.",
            createdAt: Date()
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        return list
    }

    func transcribeVoiceRecording(audioFileURL: URL) async throws -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: audioFileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        try await Task.sleep(nanoseconds: 200_000_000)
        return "Stub Whisper transcription (\(size) bytes)"
    }

    func sendVoiceRecording(
        sessionId: String,
        audioFileURL: URL,
        transcriptionHint: String,
        useKnowledgeBase: Bool
    ) async throws -> VoiceRecordingSendResult {
        let size = (try? FileManager.default.attributesOfItem(atPath: audioFileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        var list = store.messages(for: sessionId)
        let hint = transcriptionHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let userLine = hint.isEmpty
            ? "🎤 Voice (\(size) bytes)"
            : "🎤 Voice: \(hint)"
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: userLine,
            createdAt: Date()
        )
        list.append(user)

        let kb = useKnowledgeBase ? "with KB" : "empty chat"
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "Stub voice reply (\(kb)): would call POST /api/query/voice for this session.",
            createdAt: Date()
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        let stubASR = hint.isEmpty ? "Stub Whisper transcription (\(size) bytes)" : nil
        return VoiceRecordingSendResult(messages: list, transcription: stubASR)
    }

    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: audioFileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        var list = store.messages(for: sessionId)
        let voiceAtt = KBAttachment(
            id: UUID().uuidString,
            fileType: "voice",
            fileName: audioFileURL.lastPathComponent,
            fileSize: size,
            mimeType: "audio/mp4",
            downloadURL: "stub-voice",
            transcription: trimmed
        )
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: trimmed,
            createdAt: Date(),
            attachments: [voiceAtt],
            transcription: trimmed
        )
        list.append(user)
        store.replaceMessages(list, sessionId: sessionId)

        let kbNote = useKnowledgeBase ? "with KB" : "empty chat"
        let fullReply = "Stub voice reply (\(kbNote)): \(trimmed.prefix(120))"

        return AsyncThrowingStream { continuation in
            Task {
                let parts = fullReply.components(separatedBy: " ")
                for (index, part) in parts.enumerated() {
                    let chunk = index == 0 ? part : " " + part
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }
                var updated = store.messages(for: sessionId)
                let assistant = KBMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: fullReply,
                    createdAt: Date()
                )
                updated.append(assistant)
                store.replaceMessages(updated, sessionId: sessionId)
                continuation.finish()
            }
        }
    }

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<String, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        var list = store.messages(for: sessionId)
        let user = KBMessage(
            id: UUID().uuidString,
            role: .user,
            content: trimmed,
            createdAt: Date()
        )
        list.append(user)
        store.replaceMessages(list, sessionId: sessionId)

        let kbNote = useKnowledgeBase ? "with KB" : "empty chat"
        let fullReply = "Stub reply (\(kbNote)): \(trimmed.prefix(120))"

        return AsyncThrowingStream { continuation in
            Task {
                if streamInitialDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: streamInitialDelayNanoseconds)
                }
                let parts = fullReply.components(separatedBy: " ")
                for (index, part) in parts.enumerated() {
                    let chunk = index == 0 ? part : " " + part
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }
                var updated = store.messages(for: sessionId)
                let assistant = KBMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: fullReply,
                    createdAt: Date()
                )
                updated.append(assistant)
                store.replaceMessages(updated, sessionId: sessionId)
                continuation.finish()
            }
        }
    }

    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<String, Error> {
        let summary = draft.trimmedText.isEmpty
            ? "Compose: \(draft.attachments.count) files, \(draft.voiceClips.count) voice"
            : draft.trimmedText
        return try await streamTextMessage(sessionId: sessionId, text: summary, useKnowledgeBase: useKnowledgeBase)
    }
}
