import Foundation
#if canImport(WatchConnectivity)
import UIKit
import WatchConnectivity

/// Serializes Watch → iPhone voice relay work off the main thread with background execution time.
actor WatchVoiceRelayCoordinator {
    struct PendingVoiceRelay: Sendable {
        let localAudioURL: URL
        let metadata: [String: Any]
        let recordingID: String

        var hintedSessionID: String? {
            let raw = metadata[WatchConnectivityKeys.defaultSessionID] as? String
            return raw?.isEmpty == false ? raw : nil
        }
    }

    private var isProcessing = false
    private var pending: [PendingVoiceRelay] = []

    func enqueue(_ relay: PendingVoiceRelay) async {
        pending.append(relay)
        await drain()
    }

    func publishStatus(_ status: WatchRelayStatus, preview: String?, error: String?) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context = Self.baseContext(from: DefaultVoiceSessionStore.shared.load())
        Self.mergeRelayFields(into: &context, from: session.receivedApplicationContext)
        context[WatchConnectivityKeys.relayStatus] = status.rawValue
        if let preview {
            context[WatchConnectivityKeys.lastResponsePreview] = preview
            context[WatchConnectivityKeys.lastResponseError] = ""
        }
        if let error {
            context[WatchConnectivityKeys.lastResponseError] = error
        }
        do {
            try session.updateApplicationContext(context)
            WatchRelayLogger.info("Relay status=\(status.rawValue) pushed to Watch")
        } catch {
            WatchRelayLogger.error("Failed pushing relay status: \(error.localizedDescription)")
        }
    }

    private func drain() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while !pending.isEmpty {
            let relay = pending.removeFirst()
            await process(relay)
        }
    }

    private func process(_ relay: PendingVoiceRelay) async {
        let recordingID = relay.recordingID
        let localAudioURL = relay.localAudioURL
        WatchRelayLogger.info(
            "Processing relay recordingId=\(recordingID) hintedSession=\(relay.hintedSessionID ?? "nil") path=\(localAudioURL.lastPathComponent)"
        )

        publishStatus(.processing, preview: nil, error: nil)

        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "WatchVoiceRelay") {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        }

        defer {
            try? FileManager.default.removeItem(at: localAudioURL)
            if backgroundTaskID != .invalid {
                Task { @MainActor in
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        }

        guard let client = URLSessionKnowledgeBaseAPIClient() else {
            WatchRelayLogger.error("API client unavailable — check Secrets/API config on iPhone")
            publishStatus(.error, preview: nil, error: "API not configured on iPhone.")
            return
        }

        do {
            let preview = try await WatchVoiceRelayProcessor.process(
                audioURL: localAudioURL,
                hintedSessionID: relay.hintedSessionID,
                chatClient: client,
                sessionProvider: {
                    if let api = client as? KnowledgeBaseAPIClientProtocol {
                        return try await api.fetchSessions()
                    }
                    if let remote = URLSessionKnowledgeBaseAPIClient() {
                        return try await remote.fetchSessions()
                    }
                    return []
                }
            )
            WatchRelayLogger.info("Relay success recordingId=\(recordingID) previewChars=\(preview.count)")
            publishStatus(.success, preview: preview, error: nil)
        } catch {
            WatchRelayLogger.error("Relay failed recordingId=\(recordingID): \(error.localizedDescription)")
            publishStatus(.error, preview: nil, error: error.localizedDescription)
        }
    }

    private static func baseContext(from preference: DefaultVoiceSessionPreference?) -> [String: Any] {
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

    private static func mergeRelayFields(into context: inout [String: Any], from existing: [String: Any]) {
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
#endif
