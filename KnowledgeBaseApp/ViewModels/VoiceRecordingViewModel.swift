import SwiftUI
import UIKit

/// Coordinates mic gestures, AV capture, and post-record review (transcription stub until Whisper API exists).
@MainActor
@Observable
final class VoiceRecordingViewModel {
    enum Phase: Equatable {
        case idle
        case holding
        case locked
    }

    private(set) var phase: Phase = .idle
    private(set) var errorMessage: String?
    private(set) var showPostRecordReview = false
    private(set) var isSendingVoice = false
    private(set) var lastRecordedFileURL: URL?
    /// User-editable; real app will pre-fill from Whisper.
    var transcriptionDraft: String = ""
    /// Drive SwiftUI refresh while recording; updated from `refreshMeteringForDisplay()`.
    private(set) var displayedMeterLevel: Float = 0

    private let recordingService: VoiceRecordingServiceProtocol
    private let chatClient: ChatAPIClientProtocol

    private var recordingStartedForGesture = false
    private var cancelledByGesture = false
    private var lockedByGesture = false
    private var recordingStartDate: Date?

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    init(
        recordingService: VoiceRecordingServiceProtocol = VoiceRecordingService(),
        chatClient: ChatAPIClientProtocol
    ) {
        self.recordingService = recordingService
        self.chatClient = chatClient
        impactLight.prepare()
        impactMedium.prepare()
    }

    var isRecordingActive: Bool {
        phase != .idle || showPostRecordReview
    }

    func recordingStartTime() -> Date? {
        recordingStartDate
    }

    func refreshMeteringForDisplay() {
        recordingService.updateMetering()
        displayedMeterLevel = recordingService.normalizedMeterLevel
    }

    func handleDragChanged(_ translation: CGSize) {
        if !recordingStartedForGesture {
            recordingStartedForGesture = true
            errorMessage = nil
            cancelledByGesture = false
            lockedByGesture = false
            phase = .holding
            recordingStartDate = Date()
            impactLight.impactOccurred()
            Task { await startRecordingAsync() }
        }

        if RecordingGestureLogic.shouldTriggerCancel(translation: translation, isLocked: lockedByGesture, alreadyCancelled: cancelledByGesture) {
            cancelledByGesture = true
            Task { await cancelDueToGesture() }
            return
        }

        if RecordingGestureLogic.shouldTriggerLock(translation: translation, isLocked: lockedByGesture, alreadyCancelled: cancelledByGesture) {
            lockedByGesture = true
            phase = .locked
            impactMedium.impactOccurred()
        }
    }

    func handleDragEnded(_ translation: CGSize) {
        if cancelledByGesture {
            resetGestureFlags()
            return
        }

        if lockedByGesture {
            phase = .locked
            resetGestureFlagsPreservingLockedPhase()
            return
        }

        resetGestureFlags()
        Task { await finishHoldAndSend() }
    }

    func cancelLockedSession() {
        Task {
            await cancelDueToGesture()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func sendLockedSession() {
        Task { await finishHoldAndSend() }
    }

    /// Sends via `ChatAPIClientProtocol.sendVoiceRecording` (stub or `POST /api/query/voice`). Requires a session.
    func confirmPostRecordUpload(sessionId: String?, useKnowledgeBase: Bool) {
        Task {
            guard let url = lastRecordedFileURL else { return }
            guard let sessionId else {
                errorMessage = "Open a chat or create a session to send voice."
                return
            }
            isSendingVoice = true
            errorMessage = nil
            defer { isSendingVoice = false }
            do {
                let result = try await chatClient.sendVoiceRecording(
                    sessionId: sessionId,
                    audioFileURL: url,
                    transcriptionHint: transcriptionDraft,
                    useKnowledgeBase: useKnowledgeBase
                )
                let draftEmpty = transcriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if draftEmpty, let asr = result.transcription?.trimmingCharacters(in: .whitespacesAndNewlines), !asr.isEmpty {
                    transcriptionDraft = asr
                    try await Task.sleep(nanoseconds: 400_000_000)
                }
                NotificationCenter.default.post(
                    name: .kbSessionThreadDidChange,
                    object: nil,
                    userInfo: [KBNotificationUserInfoKey.sessionId: sessionId]
                )
                try? FileManager.default.removeItem(at: url)
                lastRecordedFileURL = nil
                transcriptionDraft = ""
                showPostRecordReview = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func dismissPostRecordReview() {
        if let url = lastRecordedFileURL {
            try? FileManager.default.removeItem(at: url)
            lastRecordedFileURL = nil
        }
        transcriptionDraft = ""
        showPostRecordReview = false
    }

    // MARK: - Private

    private func startRecordingAsync() async {
        do {
            try await recordingService.startRecording()
        } catch {
            if !cancelledByGesture {
                errorMessage = error.localizedDescription
            }
            phase = .idle
            recordingStartDate = nil
        }
    }

    private func cancelDueToGesture() async {
        notification.notificationOccurred(.warning)
        await cancelRecordingCleanup()
    }

    private func cancelRecordingCleanup() async {
        try? await recordingService.cancelRecording()
        phase = .idle
        recordingStartDate = nil
        lastRecordedFileURL = nil
    }

    private func finishHoldAndSend() async {
        guard !cancelledByGesture else { return }
        do {
            let url = try await recordingService.stopRecording()
            lastRecordedFileURL = url
            transcriptionDraft = ""
            phase = .idle
            recordingStartDate = nil
            showPostRecordReview = true
            notification.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            try? await recordingService.cancelRecording()
            phase = .idle
            recordingStartDate = nil
        }
    }

    private func resetGestureFlags() {
        recordingStartedForGesture = false
        cancelledByGesture = false
        lockedByGesture = false
    }

    /// After locking, keep `phase == .locked` but clear drag tracking for the next sub-gesture (Send/Cancel).
    private func resetGestureFlagsPreservingLockedPhase() {
        recordingStartedForGesture = false
        cancelledByGesture = false
        lockedByGesture = false
    }

}
