import SwiftUI
import UIKit

/// Coordinates mic gestures, AV capture, Whisper transcribe, and post-record review before sending text to chat.
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
    private(set) var isTranscribing = false
    private(set) var isSendingVoice = false
    private(set) var lastRecordedFileURL: URL?
    var transcriptionDraft: String = ""
    private let recordingService: VoiceRecordingServiceProtocol
    private let chatClient: ChatAPIClientProtocol

    /// When set, recording finishes into the chat composer draft instead of `PostRecordingReviewSheet`.
    var deferToComposer: Bool = false
    var onComposerRecordingFinished: ((URL) -> Void)?
    /// MainView hook: return `true` when the host handled routing (e.g. navigated to default chat).
    var recordingFinishedOutsideChatHandler: ((URL) -> Bool)?

    private var recordingStartedForGesture = false
    private var cancelledByGesture = false
    private var lockedByGesture = false
    private var recordingStartDate: Date?
    private var didStartTranscriptionForReview = false

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

    var canSendTranscription: Bool {
        !transcriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isTranscribing
            && !isSendingVoice
    }

    func recordingStartTime() -> Date? {
        recordingStartDate
    }

    /// Read-only metering sample for waveform UI (safe to call from `TimelineView` body).
    func currentMeterLevelForDisplay() -> Float {
        recordingService.updateMetering()
        return recordingService.normalizedMeterLevel
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
        Task { await finishHoldAndOpenReview() }
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
        Task { await finishHoldAndOpenReview() }
    }

    /// Called when the post-record sheet appears — uploads audio for Whisper only.
    func transcribeRecordedAudioIfNeeded() async {
        guard let url = lastRecordedFileURL else { return }
        guard !didStartTranscriptionForReview else { return }
        didStartTranscriptionForReview = true
        isTranscribing = true
        errorMessage = nil
        defer { isTranscribing = false }
        do {
            transcriptionDraft = try await chatClient.transcribeVoiceRecording(audioFileURL: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sends edited text; keeps the recording as a voice attachment when the audio file is still available.
    func confirmPostRecordUpload(sessionId: String?, useKnowledgeBase: Bool) {
        Task {
            let trimmed = transcriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard let sessionId else {
                errorMessage = "Open a chat or create a session to send."
                return
            }
            isSendingVoice = true
            errorMessage = nil
            defer { isSendingVoice = false }
            do {
                AssistantReplyPhaseNotification.post(sessionId: sessionId, phase: .waiting)
                let audioURL = lastRecordedFileURL
                let stream: AsyncThrowingStream<String, Error>
                if let audioURL {
                    stream = try await chatClient.streamVoiceMessage(
                        sessionId: sessionId,
                        audioFileURL: audioURL,
                        text: trimmed,
                        useKnowledgeBase: useKnowledgeBase
                    )
                } else {
                    stream = try await chatClient.streamTextMessage(
                        sessionId: sessionId,
                        text: trimmed,
                        useKnowledgeBase: useKnowledgeBase
                    )
                }
                try await AssistantReplyStreamConsumer.consume(stream) { phase in
                    AssistantReplyPhaseNotification.post(sessionId: sessionId, phase: phase)
                }

                if let url = lastRecordedFileURL {
                    try? FileManager.default.removeItem(at: url)
                    lastRecordedFileURL = nil
                }
                transcriptionDraft = ""
                showPostRecordReview = false
                didStartTranscriptionForReview = false

                NotificationCenter.default.post(
                    name: .kbSessionThreadDidChange,
                    object: nil,
                    userInfo: [KBNotificationUserInfoKey.sessionId: sessionId]
                )
                notification.notificationOccurred(.success)
            } catch {
                AssistantReplyPhaseNotification.post(sessionId: sessionId, phase: .idle)
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
        didStartTranscriptionForReview = false
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
        didStartTranscriptionForReview = false
    }

    private func finishHoldAndOpenReview() async {
        guard !cancelledByGesture else { return }
        do {
            let url = try await recordingService.stopRecording()
            lastRecordedFileURL = url
            transcriptionDraft = ""
            didStartTranscriptionForReview = false
            phase = .idle
            recordingStartDate = nil
            notification.notificationOccurred(.success)

            if deferToComposer {
                onComposerRecordingFinished?(url)
                return
            }

            if recordingFinishedOutsideChatHandler?(url) == true {
                return
            }

            showPostRecordReview = true
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

    private func resetGestureFlagsPreservingLockedPhase() {
        recordingStartedForGesture = false
        cancelledByGesture = false
        lockedByGesture = false
    }

}
