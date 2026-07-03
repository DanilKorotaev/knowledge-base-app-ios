import Foundation

enum PendingVoiceCaptureState: Equatable {
    case transcribing
    case failed(message: String)
}

/// Voice clip awaiting or retrying server-side transcription (composer flow).
struct PendingVoiceCapture: Identifiable, Equatable {
    let id: String
    let audioURL: URL
    var state: PendingVoiceCaptureState

    init(
        id: String = UUID().uuidString,
        audioURL: URL,
        state: PendingVoiceCaptureState
    ) {
        self.id = id
        self.audioURL = audioURL
        self.state = state
    }
}
