import Foundation

enum VoiceTranscriptionRetry {
    /// Silent retries on timeout / gateway errors; same `clientTranscriptionId` for server cache.
    static func transcribe(
        client: ChatAPIClientProtocol,
        audioURL: URL,
        clientTranscriptionId: String,
        maxAttempts: Int = 3
    ) async throws -> String {
        var attempt = 0
        var lastError: Error?
        while attempt < maxAttempts {
            attempt += 1
            do {
                return try await client.transcribeVoiceRecording(
                    audioFileURL: audioURL,
                    clientTranscriptionId: clientTranscriptionId
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < maxAttempts, VoicePipelineErrorMessage.isTransientTranscriptionFailure(error) else {
                    throw error
                }
                let delayNs = UInt64(300_000_000 * attempt)
                try await Task.sleep(nanoseconds: delayNs)
            }
        }
        throw lastError ?? CancellationError()
    }
}
