import AVFoundation
import Foundation

enum WatchRecordingError: Error, Equatable {
    case permissionDenied
    case recorderFailed(String)
    case notRecording
}

@MainActor
final class WatchRecordingService {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    var normalizedMeterLevel: Float {
        guard let recorder, recorder.isRecording else { return 0 }
        let power = recorder.averagePower(forChannel: 0)
        if power < -60 { return 0 }
        return Float(min(max((power + 60) / 60, 0), 1))
    }

    func updateMetering() {
        recorder?.updateMeters()
    }

    func startRecording() async throws {
        let granted = await Self.requestMicPermission()
        guard granted else { throw WatchRecordingError.permissionDenied }

        try configureSession()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-watch-\(UUID().uuidString).m4a")
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.prepareToRecord()
        guard recorder?.record() == true else {
            throw WatchRecordingError.recorderFailed("record() returned false")
        }
    }

    func stopRecording() async throws -> URL {
        guard let recorder, recorder.isRecording else { throw WatchRecordingError.notRecording }
        recorder.stop()
        guard let url = fileURL else { throw WatchRecordingError.notRecording }
        return url
    }

    func cancelRecording() {
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
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true, options: [])
    }

    private nonisolated static func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
