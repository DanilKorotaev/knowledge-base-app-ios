import Foundation
#if canImport(WatchConnectivity)
import UIKit
import WatchConnectivity

/// iPhone-side WCSession: default voice context sync + Watch voice file relay.
final class WatchVoiceSessionContextSync: NSObject, WCSessionDelegate {
    static let shared = WatchVoiceSessionContextSync()

    private var pendingPreference: DefaultVoiceSessionPreference?
    private let relayCoordinator = WatchVoiceRelayCoordinator()

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
            syncContextToWatch()
        }
    }

    func publish(_ preference: DefaultVoiceSessionPreference?) {
        activateIfNeeded()
        pendingPreference = preference
        syncContextToWatch()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            WatchRelayLogger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            WatchRelayLogger.info("WCSession activated state=\(activationState.rawValue) paired=\(session.isPaired) watchInstalled=\(session.isWatchAppInstalled)")
        }
        if activationState == .activated {
            syncContextToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        WatchRelayLogger.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        WatchRelayLogger.info("WCSession deactivated — re-activating")
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        WatchRelayLogger.info("Received voice file from Watch metadata=\(String(describing: metadata)) path=\(file.fileURL.lastPathComponent)")

        let type = metadata[WatchConnectivityKeys.messageType] as? String
        guard type == WatchConnectivityKeys.voiceQuery else {
            WatchRelayLogger.info("Ignored non-voice file type=\(type ?? "nil")")
            try? FileManager.default.removeItem(at: file.fileURL)
            return
        }

        let recordingID = metadata[WatchConnectivityKeys.recordingID] as? String ?? "unknown"
        // WCSession inbox URLs are short-lived — copy on this callback thread before any async work.
        guard let localAudioURL = WatchRelayAudioInbox.copyIncomingAudio(from: file.fileURL, recordingID: recordingID) else {
            WatchRelayLogger.error("Failed to copy incoming audio for recordingId=\(recordingID)")
            try? FileManager.default.removeItem(at: file.fileURL)
            Task {
                await relayCoordinator.publishStatus(
                    .error,
                    preview: nil,
                    error: "Could not read audio from Watch."
                )
            }
            return
        }
        try? FileManager.default.removeItem(at: file.fileURL)

        let relay = WatchVoiceRelayCoordinator.PendingVoiceRelay(
            localAudioURL: localAudioURL,
            metadata: metadata,
            recordingID: recordingID
        )
        Task {
            await relayCoordinator.enqueue(relay)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        replyHandler([WatchConnectivityKeys.messageType: "ack"])
        let type = message[WatchConnectivityKeys.messageType] as? String
        guard type == WatchConnectivityKeys.voiceQueryWake else { return }
        let recordingID = message[WatchConnectivityKeys.recordingID] as? String ?? "unknown"
        WatchRelayLogger.info("Wake message from Watch recordingId=\(recordingID) — awaiting transferFile")
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            WatchRelayLogger.error("Outgoing file transfer failed: \(error.localizedDescription)")
            Task {
                await relayCoordinator.publishStatus(.error, preview: nil, error: error.localizedDescription)
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard userInfo[WatchConnectivityKeys.messageType] as? String == WatchConnectivityKeys.watchLog else { return }
        let line = userInfo[WatchConnectivityKeys.logLine] as? String ?? userInfo.description
        WatchRelayLogger.ingestWatchLine(line)
    }

    // MARK: - Context

    private func syncContextToWatch() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let preference = pendingPreference ?? DefaultVoiceSessionStore.shared.load()
        var context = baseContext(from: preference)
        mergeRelayFields(into: &context, from: session.receivedApplicationContext)

        do {
            try session.updateApplicationContext(context)
            pendingPreference = nil
            WatchRelayLogger.info(
                "Pushed voice context sessionId=\(preference?.sessionId ?? "nil") title=\(preference?.sessionTitle ?? "nil")"
            )
        } catch {
            WatchRelayLogger.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    private func baseContext(from preference: DefaultVoiceSessionPreference?) -> [String: Any] {
        var context: [String: Any] = [:]
        if let preference, preference.isValid() {
            context[WatchConnectivityKeys.defaultSessionID] = preference.sessionId
            context[WatchConnectivityKeys.defaultSessionTitle] = preference.sessionTitle
            if let expiresAt = preference.expiresAt {
                context[WatchConnectivityKeys.expiresAt] = expiresAt.timeIntervalSince1970
            }
        } else {
            context[WatchConnectivityKeys.defaultSessionID] = ""
            context[WatchConnectivityKeys.defaultSessionTitle] = ""
        }
        return context
    }

    private func mergeRelayFields(into context: inout [String: Any], from existing: [String: Any]) {
        if let preview = existing[WatchConnectivityKeys.lastResponsePreview] {
            context[WatchConnectivityKeys.lastResponsePreview] = preview
        }
        if let error = existing[WatchConnectivityKeys.lastResponseError] {
            context[WatchConnectivityKeys.lastResponseError] = error
        }
        if let status = existing[WatchConnectivityKeys.relayStatus] {
            context[WatchConnectivityKeys.relayStatus] = status
        }
    }

}
#else
enum WatchVoiceSessionContextSync {
    static func publish(_ preference: DefaultVoiceSessionPreference?) {}
    static func activateIfNeeded() {}
}
#endif
