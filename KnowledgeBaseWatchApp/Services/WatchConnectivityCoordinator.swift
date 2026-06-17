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
        WatchRelayLog.forwardToPhone = { [weak self] line in
            self?.forwardLogLine(line)
        }
        WatchRelayLog.localSink = { line in
            print("[WatchRelay] \(line)")
        }
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

        session.transferFile(fileURL, metadata: metadata)
        WatchRelayLog.info(
            "transferFile queued recordingId=\(recordingID) sessionId=\(sessionID ?? "nil") reachable=\(session.isReachable) activation=\(session.activationState.rawValue)"
        )
    }

    func flushPendingRecordings(_ recordings: [WatchPendingRecording]) {
        guard !recordings.isEmpty else { return }
        WatchRelayLog.info("Flushing \(recordings.count) pending recording(s)")
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

    private nonisolated func forwardLogLine(_ line: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activateIfNeeded()
            let session = WCSession.default
            guard session.activationState == .activated else { return }
            session.transferUserInfo([
                WatchConnectivityKeys.messageType: WatchConnectivityKeys.watchLog,
                WatchConnectivityKeys.logLine: line,
                WatchConnectivityKeys.logTimestamp: Date().timeIntervalSince1970
            ])
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
            if let error {
                WatchRelayLog.error("WCSession activation failed: \(error.localizedDescription)")
            } else {
                WatchRelayLog.info("WCSession activated state=\(activationState.rawValue) reachable=\(session.isReachable)")
            }
            refreshFromSession(session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
            WatchRelayLog.info("iPhone reachability changed reachable=\(session.isReachable)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            voiceContext = WatchVoiceContext(applicationContext: applicationContext)
            let status = voiceContext.relayStatus?.rawValue ?? "nil"
            WatchRelayLog.info("Received application context relayStatus=\(status) sessionId=\(voiceContext.sessionID ?? "nil")")
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
