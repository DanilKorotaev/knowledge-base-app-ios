import Foundation

/// SSE stream item from `POST …/messages` (`delta` text or Cursor tool `activity`).
enum AssistantStreamEvent: Equatable, Sendable {
    case activity(label: String)
    case delta(String)
}

/// Phase + optional Cursor activity label for a single stream tick.
struct AssistantReplyStreamUpdate: Equatable {
    let phase: AssistantReplyPhase
    let activityLabel: String?
}

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
    /// Yields phase + activity updates while reading SSE; ends in `.finalizing`.
    static func consume(
        _ stream: AsyncThrowingStream<AssistantStreamEvent, Error>,
        onUpdate: @MainActor (AssistantReplyStreamUpdate) -> Void
    ) async throws {
        await onUpdate(AssistantReplyStreamUpdate(phase: .waiting, activityLabel: nil))
        var accumulated = ""
        var activityLabel: String?
        var chunkIndex = 0
        for try await event in stream {
            switch event {
            case .activity(let label):
                activityLabel = label
                let phase: AssistantReplyPhase = accumulated.isEmpty
                    ? .waiting
                    : .streaming(text: accumulated)
                await onUpdate(AssistantReplyStreamUpdate(phase: phase, activityLabel: label))
            case .delta(let chunk):
                if accumulated.isEmpty {
                    activityLabel = nil
                }
                chunkIndex += 1
                accumulated += chunk
                ChatPaginationLogger.streamingDelta(
                    index: chunkIndex,
                    deltaChars: chunk.count,
                    totalChars: accumulated.count
                )
                await onUpdate(
                    AssistantReplyStreamUpdate(phase: .streaming(text: accumulated), activityLabel: activityLabel)
                )
            }
        }
        ChatPaginationLogger.streamingFinished(chunks: chunkIndex, totalChars: accumulated.count)
        await onUpdate(AssistantReplyStreamUpdate(phase: .finalizing(text: accumulated), activityLabel: nil))
    }
}

enum AssistantReplyPhaseNotification {
    static let name = Notification.Name("kbAssistantReplyPhaseDidChange")

    static func post(sessionId: String, update: AssistantReplyStreamUpdate) {
        post(sessionId: sessionId, phase: update.phase, activityLabel: update.activityLabel)
    }

    static func post(sessionId: String, phase: AssistantReplyPhase, activityLabel: String? = nil) {
        var userInfo: [String: Any] = [
            KBNotificationUserInfoKey.sessionId: sessionId,
            KBNotificationUserInfoKey.assistantReplyPhaseKind: phase.notificationKind,
        ]
        if !phase.displayText.isEmpty {
            userInfo[KBNotificationUserInfoKey.assistantReplyPhaseText] = phase.displayText
        }
        if let activityLabel, !activityLabel.isEmpty {
            userInfo[KBNotificationUserInfoKey.assistantReplyActivityLabel] = activityLabel
        }
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    static func parse(_ notification: Notification) -> (sessionId: String, phase: AssistantReplyPhase, activityLabel: String?)? {
        guard let sessionId = notification.userInfo?[KBNotificationUserInfoKey.sessionId] as? String,
              let kind = notification.userInfo?[KBNotificationUserInfoKey.assistantReplyPhaseKind] as? String,
              let phase = AssistantReplyPhase(
                  notificationKind: kind,
                  text: notification.userInfo?[KBNotificationUserInfoKey.assistantReplyPhaseText] as? String
              )
        else { return nil }
        let activityLabel = notification.userInfo?[KBNotificationUserInfoKey.assistantReplyActivityLabel] as? String
        return (sessionId, phase, activityLabel)
    }
}
