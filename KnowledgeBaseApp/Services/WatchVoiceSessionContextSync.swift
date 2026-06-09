import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

/// iPhone-side WCSession: default voice context sync + Watch voice file relay.
final class WatchVoiceSessionContextSync: NSObject, WCSessionDelegate {
    static let shared = WatchVoiceSessionContextSync()

    private var pendingPreference: DefaultVoiceSessionPreference?
    private var isProcessingRelay = false

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
        }
    }

    func publish(_ preference: DefaultVoiceSessionPreference?) {
        activateIfNeeded()
        pendingPreference = preference
        flushPendingContextIfPossible()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            flushPendingContextIfPossible()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            await handleIncomingVoiceFile(file, session: session)
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            publishRelayStatus(.error, preview: nil, error: error.localizedDescription, session: session)
        }
    }

    // MARK: - Context

    private func flushPendingContextIfPossible() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context = baseContext(from: pendingPreference ?? DefaultVoiceSessionStore.shared.load())
        mergeRelayFields(into: &context, from: session.receivedApplicationContext)

        do {
            try session.updateApplicationContext(context)
            pendingPreference = nil
        } catch {
            // Watch app may not be installed yet.
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

    // MARK: - Relay

    @MainActor
    private func handleIncomingVoiceFile(_ file: WCSessionFile, session: WCSession) async {
        guard !isProcessingRelay else { return }
        isProcessingRelay = true
        defer { isProcessingRelay = false }

        let metadata = file.metadata ?? [:]
        let type = metadata[WatchConnectivityKeys.messageType] as? String
        guard type == WatchConnectivityKeys.voiceQuery else { return }

        let hintedSessionID = metadata[WatchConnectivityKeys.defaultSessionID] as? String
        publishRelayStatus(.processing, preview: nil, error: nil, session: session)

        defer {
            try? FileManager.default.removeItem(at: file.fileURL)
        }

        guard let client = makeChatClient() else {
            publishRelayStatus(.error, preview: nil, error: "API not configured on iPhone.", session: session)
            return
        }

        do {
            let preview = try await WatchVoiceRelayProcessor.process(
                audioURL: file.fileURL,
                hintedSessionID: hintedSessionID,
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
            publishRelayStatus(.success, preview: preview, error: nil, session: session)
        } catch {
            publishRelayStatus(.error, preview: nil, error: error.localizedDescription, session: session)
        }
    }

    private func publishRelayStatus(
        _ status: WatchRelayStatus,
        preview: String?,
        error: String?,
        session: WCSession
    ) {
        var context = baseContext(from: DefaultVoiceSessionStore.shared.load())
        mergeRelayFields(into: &context, from: session.receivedApplicationContext)
        context[WatchConnectivityKeys.relayStatus] = status.rawValue
        if let preview {
            context[WatchConnectivityKeys.lastResponsePreview] = preview
            context[WatchConnectivityKeys.lastResponseError] = ""
        }
        if let error {
            context[WatchConnectivityKeys.lastResponseError] = error
        }
        try? session.updateApplicationContext(context)
    }

    private func makeChatClient() -> ChatAPIClientProtocol? {
        URLSessionKnowledgeBaseAPIClient()
    }
}
#else
enum WatchVoiceSessionContextSync {
    static func publish(_ preference: DefaultVoiceSessionPreference?) {}
    static func activateIfNeeded() {}
}
#endif
