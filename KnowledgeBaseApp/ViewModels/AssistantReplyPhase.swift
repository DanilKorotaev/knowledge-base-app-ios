import Foundation

/// UI phase for an in-flight assistant reply (text send or voice-from-chat).
enum AssistantReplyPhase: Equatable {
    case idle
    case waiting
    case streaming(text: String)
    case finalizing(text: String)

    var showsPlaceholder: Bool {
        switch self {
        case .idle: false
        case .waiting, .streaming, .finalizing: true
        }
    }

    var displayText: String {
        switch self {
        case .idle, .waiting: ""
        case .streaming(let text), .finalizing(let text): text
        }
    }

    var showsTypingIndicator: Bool {
        switch self {
        case .waiting: true
        case .streaming(let text): text.isEmpty
        case .finalizing, .idle: false
        }
    }

    var showsPendingSpinner: Bool {
        if case .waiting = self { return true }
        if case .streaming(let text) = self, text.isEmpty { return true }
        return false
    }

    // MARK: - Notification bridge (voice send from mic bar)

    var notificationKind: String {
        switch self {
        case .idle: "idle"
        case .waiting: "waiting"
        case .streaming: "streaming"
        case .finalizing: "finalizing"
        }
    }

    init?(notificationKind: String, text: String?) {
        switch notificationKind {
        case "idle": self = .idle
        case "waiting": self = .waiting
        case "streaming": self = .streaming(text: text ?? "")
        case "finalizing": self = .finalizing(text: text ?? "")
        default: return nil
        }
    }
}

enum AssistantReplyStreamConsumer {
    /// Yields phase updates while reading SSE chunks; ends in `.finalizing`.
    static func consume(
        _ stream: AsyncThrowingStream<String, Error>,
        onPhaseChange: @MainActor (AssistantReplyPhase) -> Void
    ) async throws {
        await onPhaseChange(.waiting)
        var accumulated = ""
        var chunkIndex = 0
        for try await chunk in stream {
            chunkIndex += 1
            accumulated += chunk
            ChatPaginationLogger.streamingDelta(
                index: chunkIndex,
                deltaChars: chunk.count,
                totalChars: accumulated.count
            )
            await onPhaseChange(.streaming(text: accumulated))
        }
        ChatPaginationLogger.streamingFinished(chunks: chunkIndex, totalChars: accumulated.count)
        await onPhaseChange(.finalizing(text: accumulated))
    }
}

enum AssistantReplyPhaseNotification {
    static let name = Notification.Name("kbAssistantReplyPhaseDidChange")

    static func post(sessionId: String, phase: AssistantReplyPhase) {
        var userInfo: [String: Any] = [
            KBNotificationUserInfoKey.sessionId: sessionId,
            KBNotificationUserInfoKey.assistantReplyPhaseKind: phase.notificationKind,
        ]
        if !phase.displayText.isEmpty {
            userInfo[KBNotificationUserInfoKey.assistantReplyPhaseText] = phase.displayText
        }
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    static func parse(_ notification: Notification) -> (sessionId: String, phase: AssistantReplyPhase)? {
        guard let sessionId = notification.userInfo?[KBNotificationUserInfoKey.sessionId] as? String,
              let kind = notification.userInfo?[KBNotificationUserInfoKey.assistantReplyPhaseKind] as? String,
              let phase = AssistantReplyPhase(
                  notificationKind: kind,
                  text: notification.userInfo?[KBNotificationUserInfoKey.assistantReplyPhaseText] as? String
              )
        else { return nil }
        return (sessionId, phase)
    }
}
