import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
@Observable
final class WatchConnectivityCoordinator: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityCoordinator()

    private(set) var voiceContext = WatchVoiceContext(applicationContext: [:])
    private(set) var isPhoneReachable = false
    private(set) var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
    }

    func activateIfNeeded() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
        } else {
            refreshFromSession(session)
        }
    }

    func sendVoiceRecording(fileURL: URL, recordingID: String, sessionID: String?) {
        activateIfNeeded()
        let session = WCSession.default

        var metadata: [String: Any] = [
            WatchConnectivityKeys.messageType: WatchConnectivityKeys.voiceQuery,
            WatchConnectivityKeys.recordingID: recordingID
        ]
        if let sessionID, !sessionID.isEmpty {
            metadata[WatchConnectivityKeys.defaultSessionID] = sessionID
        }

        if session.isReachable {
            session.transferFile(fileURL, metadata: metadata)
        } else {
            session.transferFile(fileURL, metadata: metadata)
        }
    }

    func flushPendingRecordings(_ recordings: [WatchPendingRecording]) {
        guard !recordings.isEmpty else { return }
        activateIfNeeded()
        let store = WatchPendingRecordingStore.shared
        for recording in recordings {
            let url = store.fileURL(for: recording)
            sendVoiceRecording(
                fileURL: url,
                recordingID: recording.id,
                sessionID: recording.sessionID
            )
        }
    }

    private func refreshFromSession(_ session: WCSession) {
        activationState = session.activationState
        isPhoneReachable = session.isReachable
        voiceContext = WatchVoiceContext(applicationContext: session.receivedApplicationContext)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            refreshFromSession(session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            voiceContext = WatchVoiceContext(applicationContext: applicationContext)
        }
    }
}
#else
@MainActor
@Observable
final class WatchConnectivityCoordinator {
    static let shared = WatchConnectivityCoordinator()
    var voiceContext = WatchVoiceContext(applicationContext: [:])
    var isPhoneReachable = false
    func activateIfNeeded() {}
    func sendVoiceRecording(fileURL: URL, recordingID: String, sessionID: String?) {}
    func flushPendingRecordings(_ recordings: [WatchPendingRecording]) {}
}
#endif
