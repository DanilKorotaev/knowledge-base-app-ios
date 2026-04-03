import Foundation

/// Uploads recorded audio + user-edited transcript to KB App API (future).
protocol VoiceUploadClientProtocol: Sendable {
    func uploadRecording(audioFileURL: URL, transcription: String) async throws
}

struct StubVoiceUploadClient: VoiceUploadClientProtocol {
    func uploadRecording(audioFileURL: URL, transcription: String) async throws {
        // KB App API: multipart upload + Whisper pipeline — not implemented yet.
        _ = (audioFileURL, transcription)
    }
}
