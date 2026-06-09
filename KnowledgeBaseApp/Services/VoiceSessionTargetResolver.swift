import Foundation

enum VoiceSessionTargetResolver {
    /// open chat > valid default > first session in list
    static func resolve(
        activeSessionId: String?,
        defaultPreference: DefaultVoiceSessionPreference?,
        orderedSessionIds: [String],
        now: Date = Date()
    ) -> String? {
        if let activeSessionId, orderedSessionIds.contains(activeSessionId) {
            return activeSessionId
        }
        if let defaultPreference,
           defaultPreference.isValid(at: now),
           orderedSessionIds.contains(defaultPreference.sessionId) {
            return defaultPreference.sessionId
        }
        return orderedSessionIds.first
    }
}
