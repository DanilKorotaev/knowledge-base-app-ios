import Foundation

/// Pure rules for locked voice recording pause/resume (testable without AVFoundation).
enum VoiceRecordingSessionLogic: Sendable {
    static func shouldAutoPauseOnBackground(isLocked: Bool, isPaused: Bool) -> Bool {
        isLocked && !isPaused
    }

    static func canManualPause(isLocked: Bool, isPaused: Bool) -> Bool {
        isLocked && !isPaused
    }

    static func canResume(isLocked: Bool, isPaused: Bool) -> Bool {
        isLocked && isPaused
    }

    static func canFinish(isLocked: Bool) -> Bool {
        isLocked
    }
}
