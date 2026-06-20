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
    /// Called on the main actor whenever `voiceContext` changes (application context from iPhone).
    var onVoiceContextDidChange: ((WatchVoiceContext) -> Void)?
    /// Called on the main actor when iPhone reachability changes.
    var onReachabilityDidChange: ((Bool) -> Void)?
    /// URLs passed to `transferFile` — must stay on disk until `didFinish fileTransfer`.
    private var outgoingTransferURLs: Set<URL> = []

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

        if session.isReachable {
            var wakeMetadata = metadata
            wakeMetadata[WatchConnectivityKeys.messageType] = WatchConnectivityKeys.voiceQueryWake
            session.sendMessage(
                wakeMetadata,
                replyHandler: { _ in
                    WatchRelayLog.info("iPhone ack wake recordingId=\(recordingID)")
                },
                errorHandler: { error in
                    WatchRelayLog.error("sendMessage wake failed recordingId=\(recordingID): \(error.localizedDescription)")
                }
            )
            WatchRelayLog.info("sendMessage wake queued recordingId=\(recordingID)")
        }

        session.transferFile(fileURL, metadata: metadata)
        outgoingTransferURLs.insert(fileURL)
        WatchRelayLog.info(
            "transferFile queued recordingId=\(recordingID) sessionId=\(sessionID ?? "nil") reachable=\(session.isReachable) activation=\(session.activationState.rawValue) path=\(fileURL.lastPathComponent)"
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
        applyVoiceContext(WatchVoiceContext(applicationContext: session.receivedApplicationContext))
    }

    private func applyVoiceContext(_ newContext: WatchVoiceContext) {
        voiceContext = newContext
        onVoiceContextDidChange?(newContext)
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
            onReachabilityDidChange?(session.isReachable)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            applyVoiceContext(WatchVoiceContext(applicationContext: applicationContext))
            let status = voiceContext.relayStatus?.rawValue ?? "nil"
            WatchRelayLog.info("Received application context relayStatus=\(status) sessionId=\(voiceContext.sessionID ?? "nil")")
            if voiceContext.relayStatus == .success || voiceContext.relayStatus == .error {
                purgeTransferredAudioFiles()
            }
        }
    }

    private func purgeTransferredAudioFiles() {
        for url in outgoingTransferURLs {
            try? FileManager.default.removeItem(at: url)
        }
        outgoingTransferURLs.removeAll()
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            let url = fileTransfer.file.fileURL
            let recordingID = fileTransfer.file.metadata?[WatchConnectivityKeys.recordingID] as? String ?? "unknown"
            if let error {
                outgoingTransferURLs.remove(url)
                try? FileManager.default.removeItem(at: url)
                WatchRelayLog.error("transferFile failed recordingId=\(recordingID): \(error.localizedDescription)")
            } else {
                WatchRelayLog.info("transferFile completed recordingId=\(recordingID) — keeping file until relay ack")
            }
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
