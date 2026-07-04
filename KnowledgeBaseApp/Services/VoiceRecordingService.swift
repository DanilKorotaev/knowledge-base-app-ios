import AVFoundation
import Foundation

enum VoiceRecordingSessionPhase: Equatable {
    case idle
    case recording
    case paused
}

protocol VoiceRecordingServiceProtocol: AnyObject {
    var sessionPhase: VoiceRecordingSessionPhase { get }
    /// Normalized meter 0...1 after `updateMetering()` while recording.
    var normalizedMeterLevel: Float { get }

    func elapsedDuration(at date: Date) -> TimeInterval
    func updateMetering()
    func startRecording() async throws
    func pauseRecording() async throws
    func resumeRecording() async throws
    func stopRecording() async throws -> URL
    func cancelRecording() async throws
}

enum VoiceRecordingError: Error, Equatable {
    case permissionDenied
    case recorderFailed(String)
    case notRecording
    case invalidState(String)
}

final class VoiceRecordingService: VoiceRecordingServiceProtocol {
    private var recorder: AVAudioRecorder?
    private var currentSegmentURL: URL?
    private var completedSegmentURLs: [URL] = []
    private var accumulatedDuration: TimeInterval = 0
    private var activeSegmentStartDate: Date?

    private(set) var sessionPhase: VoiceRecordingSessionPhase = .idle

    var normalizedMeterLevel: Float {
        guard let recorder, recorder.isRecording else { return 0 }
        let power = recorder.averagePower(forChannel: 0)
        if power < -60 { return 0 }
        let clamped = min(max((power + 60) / 60, 0), 1)
        return Float(clamped)
    }

    func elapsedDuration(at date: Date) -> TimeInterval {
        switch sessionPhase {
        case .idle:
            return 0
        case .paused:
            return accumulatedDuration
        case .recording:
            guard let activeSegmentStartDate else { return accumulatedDuration }
            return accumulatedDuration + max(0, date.timeIntervalSince(activeSegmentStartDate))
        }
    }

    func updateMetering() {
        recorder?.updateMeters()
    }

    func startRecording() async throws {
        let granted = await Self.requestMicPermission()
        guard granted else { throw VoiceRecordingError.permissionDenied }

        try resetSessionArtifacts()
        try configureSession()
        try beginSegment()
        sessionPhase = .recording
    }

    func pauseRecording() async throws {
        guard sessionPhase == .recording else {
            throw VoiceRecordingError.invalidState("Cannot pause while not recording")
        }
        try await finishActiveSegment()
        sessionPhase = .paused
    }

    func resumeRecording() async throws {
        guard sessionPhase == .paused else {
            throw VoiceRecordingError.invalidState("Cannot resume while not paused")
        }
        try configureSession()
        try beginSegment()
        sessionPhase = .recording
    }

    func stopRecording() async throws -> URL {
        switch sessionPhase {
        case .idle:
            throw VoiceRecordingError.notRecording
        case .recording:
            try await finishActiveSegment()
        case .paused:
            break
        }

        let segments = completedSegmentURLs
        guard !segments.isEmpty else {
            throw VoiceRecordingError.notRecording
        }

        let merged = try await VoiceAudioMerger.mergeSegments(segments)
        if merged != segments[0] || segments.count > 1 {
            for url in segments where url != merged {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try resetSessionArtifacts()
        sessionPhase = .idle
        return merged
    }

    func cancelRecording() async throws {
        if sessionPhase == .recording {
            recorder?.stop()
        }
        deleteSegmentFiles(completedSegmentURLs + [currentSegmentURL].compactMap { $0 })
        try resetSessionArtifacts()
        sessionPhase = .idle
    }

    // MARK: - Private

    private func beginSegment() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-voice-seg-\(UUID().uuidString).m4a")
        currentSegmentURL = url

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
        activeSegmentStartDate = Date()
    }

    private func finishActiveSegment() async throws {
        guard sessionPhase == .recording else { return }
        guard let recorder, recorder.isRecording else {
            throw VoiceRecordingError.notRecording
        }
        recorder.stop()

        guard let url = currentSegmentURL else {
            throw VoiceRecordingError.notRecording
        }

        let segmentDuration = try await Self.assetDuration(url: url)
        accumulatedDuration += segmentDuration
        completedSegmentURLs.append(url)

        self.recorder = nil
        currentSegmentURL = nil
        activeSegmentStartDate = nil
    }

    private func resetSessionArtifacts() throws {
        recorder?.stop()
        recorder = nil
        currentSegmentURL = nil
        completedSegmentURLs = []
        accumulatedDuration = 0
        activeSegmentStartDate = nil
    }

    private func deleteSegmentFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func assetDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return seconds
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: [])
    }

    private nonisolated static func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}
