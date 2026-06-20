import Foundation

enum WatchVoiceRelayProcessor {
    private static let previewLimit = 200

    static func process(
        audioURL: URL,
        hintedSessionID: String?,
        chatClient: ChatAPIClientProtocol,
        sessionProvider: () async throws -> [KBSession]
    ) async throws -> String {
        WatchRelayLogger.info("Relay processor start hintedSession=\(hintedSessionID ?? "nil")")
        let sessions = try await sessionProvider()
        let orderedIDs = sessions.map(\.id)
        WatchRelayLogger.info("Fetched \(sessions.count) session(s) for relay")
        let store = DefaultVoiceSessionStore.shared

        let targetID: String?
        if let hintedSessionID,
           !hintedSessionID.isEmpty,
           orderedIDs.contains(hintedSessionID) {
            targetID = hintedSessionID
        } else {
            targetID = VoiceSessionTargetResolver.resolve(
                activeSessionId: nil,
                defaultPreference: store.load(),
                orderedSessionIds: orderedIDs
            )
        }

        guard let sessionID = targetID else {
            WatchRelayLogger.error("No target session — set voice default on iPhone")
            throw WatchRelayError.noTargetSession
        }
        WatchRelayLogger.info("Relay target sessionId=\(sessionID)")

        let transcription = try await chatClient.transcribeVoiceRecording(audioFileURL: audioURL)
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            WatchRelayLogger.error("Empty transcription")
            throw WatchRelayError.emptyTranscription
        }
        WatchRelayLogger.info("Transcription chars=\(trimmed.count)")

        let useKB = DefaultVoiceSessionStore.shared.load() != nil
        let stream = try await chatClient.streamVoiceMessage(
            sessionId: sessionID,
            audioFileURL: audioURL,
            text: trimmed,
            useKnowledgeBase: useKB
        )

        var finalText = trimmed
        try await AssistantReplyStreamConsumer.consume(stream) { update in
            switch update.phase {
            case .finalizing(let text):
                finalText = text
            case .streaming(let text) where !text.isEmpty:
                finalText = text
            default:
                break
            }
        }

        NotificationCenter.default.post(
            name: .kbSessionThreadDidChange,
            object: nil,
            userInfo: [KBNotificationUserInfoKey.sessionId: sessionID]
        )

        let cleaned = TerminalSanitizer.stripEscapeSequences(finalText)
        return String(cleaned.prefix(previewLimit))
    }
}

enum WatchRelayError: LocalizedError {
    case noTargetSession
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .noTargetSession:
            return "Set a voice default session on iPhone."
        case .emptyTranscription:
            return "Could not transcribe the recording."
        }
    }
}
