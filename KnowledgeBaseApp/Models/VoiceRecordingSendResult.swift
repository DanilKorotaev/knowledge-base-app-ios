import Foundation

/// Result of `POST /api/query/voice`: updated thread plus optional Whisper text from the server.
struct VoiceRecordingSendResult: Sendable, Equatable {
    let messages: [KBMessage]
    let transcription: String?
}
