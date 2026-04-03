import AVFoundation
import Foundation

protocol VoiceRecordingServiceProtocol: AnyObject {
    /// Normalized meter 0...1 after `updateMetering()` while recording.
    var normalizedMeterLevel: Float { get }

    func updateMetering()
    func startRecording() async throws
    func stopRecording() async throws -> URL
    func cancelRecording() async throws
}

enum VoiceRecordingError: Error, Equatable {
    case permissionDenied
    case recorderFailed(String)
    case notRecording
}

final class VoiceRecordingService: VoiceRecordingServiceProtocol {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    var normalizedMeterLevel: Float {
        guard let recorder, recorder.isRecording else { return 0 }
        let power = recorder.averagePower(forChannel: 0)
        if power < -60 { return 0 }
        let clamped = min(max((power + 60) / 60, 0), 1)
        return Float(clamped)
    }

    func updateMetering() {
        recorder?.updateMeters()
    }

    func startRecording() async throws {
        let granted = await Self.requestMicPermission()
        guard granted else { throw VoiceRecordingError.permissionDenied }

        try configureSession()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-voice-\(UUID().uuidString).m4a")
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.prepareToRecord()
        guard recorder?.record() == true else {
            throw VoiceRecordingError.recorderFailed("record() returned false")
        }
    }

    func stopRecording() async throws -> URL {
        guard let recorder, recorder.isRecording else { throw VoiceRecordingError.notRecording }
        recorder.stop()
        guard let url = fileURL else { throw VoiceRecordingError.notRecording }
        return url
    }

    func cancelRecording() async throws {
        if let recorder, recorder.isRecording {
            recorder.stop()
        }
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        fileURL = nil
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: [])
    }

    private nonisolated static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
