import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

/// Activates WCSession and pushes default voice session metadata to Apple Watch.
final class WatchVoiceSessionContextSync: NSObject, WCSessionDelegate {
    static let shared = WatchVoiceSessionContextSync()

    private var pendingPreference: DefaultVoiceSessionPreference?

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

    private func flushPendingContextIfPossible() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context: [String: Any] = [:]
        if let preference = pendingPreference {
            context["default_session_id"] = preference.sessionId
            context["default_session_title"] = preference.sessionTitle
            if let expiresAt = preference.expiresAt {
                context["expires_at"] = expiresAt.timeIntervalSince1970
            }
        } else {
            context["default_session_id"] = ""
            context["default_session_title"] = ""
        }

        do {
            try session.updateApplicationContext(context)
            pendingPreference = nil
        } catch {
            // Watch app may not be installed yet.
        }
    }

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
}
#else
enum WatchVoiceSessionContextSync {
    static func publish(_ preference: DefaultVoiceSessionPreference?) {}
    static func activateIfNeeded() {}
}
#endif
