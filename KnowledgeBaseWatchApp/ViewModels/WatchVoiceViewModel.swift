import AVFoundation
import Foundation
import WatchKit

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WatchVoicePhase: Equatable {
    case idle
    case recording
    case sending
}

@MainActor
@Observable
final class WatchVoiceViewModel {
    private(set) var phase: WatchVoicePhase = .idle
    private(set) var recordingStartDate: Date?
    private(set) var pendingRecordings: [WatchPendingRecording] = []
    private(set) var statusMessage: String?

    private let recordingService = WatchRecordingService()
    private let connectivity = WatchConnectivityCoordinator.shared
    private let pendingStore = WatchPendingRecordingStore.shared

    var voiceContext: WatchVoiceContext {
        connectivity.voiceContext
    }

    var isPhoneReachable: Bool {
        connectivity.isPhoneReachable
    }

    var pendingCount: Int {
        pendingRecordings.count
    }

    func onAppear() {
        connectivity.activateIfNeeded()
        reloadPending()
    }

    func onReachabilityChanged() {
        guard connectivity.isPhoneReachable else { return }
        let pending = pendingStore.loadAll()
        guard !pending.isEmpty else { return }
        connectivity.flushPendingRecordings(pending)
    }

    func reloadPending() {
        pendingRecordings = pendingStore.loadAll()
    }

    func startRecording() {
        guard phase == .idle else { return }
        statusMessage = nil
        phase = .recording
        recordingStartDate = Date()
        Task {
            do {
                try await recordingService.startRecording()
            } catch {
                phase = .idle
                recordingStartDate = nil
                statusMessage = error.localizedDescription
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    func cancelRecording() {
        recordingService.cancelRecording()
        phase = .idle
        recordingStartDate = nil
        WKInterfaceDevice.current().play(.click)
    }

    func finishRecording() {
        guard phase == .recording else { return }
        phase = .sending
        Task {
            do {
                let url = try await recordingService.stopRecording()
                let recordingID = UUID().uuidString
                let sessionID = voiceContext.sessionID

                #if canImport(WatchConnectivity)
                connectivity.sendVoiceRecording(
                    fileURL: url,
                    recordingID: recordingID,
                    sessionID: sessionID
                )
                try? FileManager.default.removeItem(at: url)
                if connectivity.isPhoneReachable {
                    statusMessage = "Sent to iPhone"
                } else {
                    statusMessage = "Queued for iPhone"
                }
                WKInterfaceDevice.current().play(.success)
                #else
                _ = try pendingStore.saveRecording(from: url, sessionID: sessionID)
                try? FileManager.default.removeItem(at: url)
                reloadPending()
                statusMessage = "Saved locally"
                #endif
            } catch {
                statusMessage = error.localizedDescription
                WKInterfaceDevice.current().play(.failure)
            }
            phase = .idle
            recordingStartDate = nil
        }
    }

    func meterLevelForDisplay() -> Float {
        recordingService.normalizedMeterLevel
    }

    func speakLastResponse() {
        guard let text = voiceContext.lastResponsePreview, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        AVSpeechSynthesizer().speak(utterance)
    }
}
