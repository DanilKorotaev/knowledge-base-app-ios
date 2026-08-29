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

    /// Assistant reply as SSE events (`activity` progress + `delta` text). Implementations add the user message before the first yield (stub); HTTP runs `POST …/messages` first, then yields assistant events.
    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>

    /// Text + voice file: `POST …/messages/voice` (multipart + SSE). Saves audio and transcription on the server.
    func streamVoiceMessage(
        sessionId: String,
        audioFileURL: URL,
        text: String,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>

    /// Text + multiple files/voice clips: `POST …/messages/compose` (multipart + SSE).
    func streamComposedMessage(
        sessionId: String,
        draft: ChatComposerDraft,
        useKnowledgeBase: Bool
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>

    /// Structured UI button tap: `POST …/ui-events`.
    func sendUIEvent(
        sessionId: String,
        actionId: String,
        componentId: String,
        clientSchemaVersion: Int,
        values: [String: StructuredUIFormValue]?
    ) async throws -> KBUIEventResponse
}

extension ChatAPIClientProtocol {
    func sendUIEvent(
        sessionId: String,
        actionId: String,
        componentId: String,
        clientSchemaVersion: Int,
        values: [String: StructuredUIFormValue]? = nil
    ) async throws -> KBUIEventResponse {
        throw KnowledgeBaseAPIError.decodingFailed
    }
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
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
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
                    continuation.yield(.delta(chunk))
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

    func streamTextMessage(sessionId: String, text: String, useKnowledgeBase: Bool) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
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
                    continuation.yield(.delta(chunk))
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
    ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
        let summary = draft.trimmedText.isEmpty
            ? "Compose: \(draft.attachments.count) files, \(draft.voiceClips.count) voice"
            : draft.trimmedText
        return try await streamTextMessage(sessionId: sessionId, text: summary, useKnowledgeBase: useKnowledgeBase)
    }

    func sendUIEvent(
        sessionId: String,
        actionId: String,
        componentId: String,
        clientSchemaVersion: Int,
        values: [String: StructuredUIFormValue]? = nil
    ) async throws -> KBUIEventResponse {
        let result = StubStructuredUIMockFlow.apply(
            actionId: actionId,
            componentId: componentId,
            values: values
        )
        var list = store.messages(for: sessionId)
        if let values, !values.isEmpty,
           let index = list.lastIndex(where: { $0.role == .assistant && $0.structuredUI != nil }),
           let document = list[index].structuredUI {
            let previous = list[index]
            list[index] = KBMessage(
                id: previous.id,
                role: previous.role,
                content: previous.content,
                createdAt: previous.createdAt,
                attachments: previous.attachments,
                contentFormat: previous.contentFormat,
                transcription: previous.transcription,
                relatedChangedFiles: previous.relatedChangedFiles,
                relatedChangedFilesSource: previous.relatedChangedFilesSource,
                structuredUI: StructuredUIFormDraft.applying(values, to: document)
            )
        }
        if let userContent = result.userContent {
            list.append(
                KBMessage(
                    id: UUID().uuidString,
                    role: .user,
                    content: userContent,
                    createdAt: Date()
                )
            )
        }
        let assistant = KBMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: result.assistantContent,
            createdAt: Date(),
            structuredUI: result.screen
        )
        list.append(assistant)
        store.replaceMessages(list, sessionId: sessionId)
        return KBUIEventResponse(screen: result.screen, messages: list)
    }
}

enum StubStructuredUIMockFlow {
    struct Result {
        let screen: KBStructuredUIDocument
        let userContent: String?
        let assistantContent: String
    }

    static func apply(
        actionId: String,
        componentId: String,
        values: [String: StructuredUIFormValue]? = nil
    ) -> Result {
        _ = componentId
        switch actionId {
        case "start":
            return Result(
                screen: welcomeScreen(),
                userContent: nil,
                assistantContent: "Interactive UI ready."
            )
        case "confirm_yes":
            return Result(
                screen: confirmedScreen(),
                userContent: "[UI] Yes",
                assistantContent: "You selected Yes."
            )
        case "confirm_no":
            return Result(
                screen: declinedScreen(),
                userContent: "[UI] No",
                assistantContent: "You selected No."
            )
        case "open_form":
            return Result(
                screen: formScreen(),
                userContent: "[UI] Open form",
                assistantContent: "Fill the form, then submit."
            )
        case "submit_form":
            let summary = StructuredUIFormDraft.summaryLine(from: values ?? [:])
            return Result(
                screen: formSubmittedScreen(summary: summary),
                userContent: summary,
                assistantContent: "Form received."
            )
        case "done":
            return Result(
                screen: finishedScreen(),
                userContent: "[UI] Done",
                assistantContent: "Flow finished."
            )
        case "dismiss":
            return Result(
                screen: dismissedScreen(),
                userContent: nil,
                assistantContent: "Interactive UI closed."
            )
        default:
            fatalError("Unknown structured UI action: \(actionId)")
        }
    }

    private static func welcomeScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Choose an action"),
                    node(type: "text", id: "subtitle", text: "Mock structured UI flow (MVP)."),
                    node(type: "button", id: "btn_yes", label: "Yes", actionId: "confirm_yes"),
                    node(type: "button", id: "btn_no", label: "No", actionId: "confirm_no"),
                    node(type: "button", id: "btn_form", label: "Open form", actionId: "open_form"),
                ]
            )
        )
    }

    private static func formScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Preferences"),
                    node(
                        type: "checkbox",
                        id: "notify",
                        label: "Notify me",
                        value: .bool(true)
                    ),
                    node(
                        type: "radio_group",
                        id: "theme",
                        label: "Theme",
                        value: .string("system"),
                        options: [
                            KBStructuredUIOption(id: "system", label: "System"),
                            KBStructuredUIOption(id: "light", label: "Light"),
                            KBStructuredUIOption(id: "dark", label: "Dark"),
                        ]
                    ),
                    node(
                        type: "select",
                        id: "topics",
                        label: "Topics",
                        value: .strings(["ios"]),
                        options: [
                            KBStructuredUIOption(id: "ios", label: "iOS"),
                            KBStructuredUIOption(id: "bot", label: "Bot"),
                            KBStructuredUIOption(id: "infra", label: "Infra"),
                        ],
                        multi: true
                    ),
                    node(
                        type: "text_field",
                        id: "note",
                        label: "Note",
                        value: .string(""),
                        placeholder: "Optional note",
                        maxLength: 120
                    ),
                    node(
                        type: "button",
                        id: "btn_submit",
                        label: "Submit",
                        actionId: "submit_form",
                        submit: true
                    ),
                ]
            )
        )
    }

    private static func formSubmittedScreen(summary: String) -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Submitted"),
                    node(type: "text", id: "body", text: summary),
                    node(type: "button", id: "btn_done", label: "Done", actionId: "done"),
                ]
            )
        )
    }

    private static func confirmedScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Confirmed"),
                    node(type: "text", id: "body", text: "You chose Yes. Tap Done to finish."),
                    node(type: "button", id: "btn_done", label: "Done", actionId: "done"),
                ]
            )
        )
    }

    private static func declinedScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Declined"),
                    node(type: "text", id: "body", text: "You chose No. Tap Done to finish."),
                    node(type: "button", id: "btn_done", label: "Done", actionId: "done"),
                ]
            )
        )
    }

    private static func finishedScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Finished"),
                    node(type: "text", id: "body", text: "Mock flow complete."),
                ]
            )
        )
    }

    private static func dismissedScreen() -> KBStructuredUIDocument {
        screenDocument(
            root: node(
                type: "vstack",
                id: "root",
                children: [
                    node(type: "text", id: "title", text: "Interactive UI off"),
                    node(type: "text", id: "body", text: "Mode turned off. You can continue in the chat."),
                ]
            )
        )
    }

    private static func screenDocument(root: KBStructuredUINode) -> KBStructuredUIDocument {
        KBStructuredUIDocument(schemaVersion: 1, screen: root)
    }

    private static func node(
        type: String,
        id: String,
        text: String? = nil,
        label: String? = nil,
        actionId: String? = nil,
        children: [KBStructuredUINode]? = nil,
        value: StructuredUIFormValue? = nil,
        placeholder: String? = nil,
        maxLength: Int? = nil,
        options: [KBStructuredUIOption]? = nil,
        multi: Bool? = nil,
        submit: Bool? = nil
    ) -> KBStructuredUINode {
        KBStructuredUINode(
            type: type,
            id: id,
            text: text,
            label: label,
            actionId: actionId,
            children: children,
            value: value,
            placeholder: placeholder,
            maxLength: maxLength,
            options: options,
            multi: multi,
            submit: submit
        )
    }
}
