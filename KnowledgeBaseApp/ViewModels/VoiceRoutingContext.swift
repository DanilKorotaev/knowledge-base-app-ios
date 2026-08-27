import Foundation

/// Session + KB toggle for voice routing (open chat, Watch, and record deep links).
@Observable
@MainActor
final class VoiceRoutingContext {
    var activeSessionId: String?
    var useKnowledgeBase: Bool = true
    /// When true, finished recordings append to the open chat composer instead of the review sheet.
    var usesComposerDraft: Bool = false
    /// One-shot notice after TTL expiry (shown on the sessions list; dismiss with `dismissDefaultExpiredNotice()`).
    var defaultExpiredNotice: VoiceDefaultExpiredNotice?
    /// Voice file handed off into a chat composer (e.g. after Watch relay).
    var pendingComposerVoice: (sessionId: String, audioURL: URL)?

    private let store: DefaultVoiceSessionStoreProtocol

    init(store: DefaultVoiceSessionStoreProtocol = DefaultVoiceSessionStore.shared) {
        self.store = store
    }

    var defaultPreference: DefaultVoiceSessionPreference? {
        store.load()
    }

    var validDefaultPreference: DefaultVoiceSessionPreference? {
        guard let preference = store.load(), preference.isValid() else { return nil }
        return preference
    }

    func isDefaultVoiceSession(_ sessionId: String) -> Bool {
        validDefaultPreference?.sessionId == sessionId
    }

    func resolveVoiceTargetSessionId(in sessions: [KBSession], now: Date = Date()) -> String? {
        VoiceSessionTargetResolver.resolve(
            activeSessionId: activeSessionId,
            defaultPreference: store.load(),
            orderedSessionIds: sessions.map(\.id),
            now: now
        )
    }

    func resolveVoiceTargetSession(in sessions: [KBSession], now: Date = Date()) -> KBSession? {
        guard let id = resolveVoiceTargetSessionId(in: sessions, now: now) else { return nil }
        return sessions.first { $0.id == id }
    }

    func setDefaultVoiceSession(_ session: KBSession, ttl: DefaultVoiceSessionTTL, now: Date = Date()) {
        let current = validDefaultPreference
        var previousId: String?
        var previousTitle: String?
        if let current, current.sessionId != session.id {
            previousId = current.sessionId
            previousTitle = current.sessionTitle
        }

        let preference = DefaultVoiceSessionPreference(
            sessionId: session.id,
            sessionTitle: session.title,
            expiresAt: ttl.expirationDate(from: now),
            previousSessionId: previousId,
            previousSessionTitle: previousTitle
        )
        store.save(preference)
        defaultExpiredNotice = nil
        WatchVoiceSessionContextSync.shared.publish(preference)
    }

    func clearDefaultVoiceSession() {
        store.clear()
        defaultExpiredNotice = nil
        WatchVoiceSessionContextSync.shared.publish(nil)
    }

    func dismissDefaultExpiredNotice() {
        defaultExpiredNotice = nil
    }

    func refreshExpiryIfNeeded(now: Date = Date()) {
        guard let preference = store.load() else { return }
        guard let expiresAt = preference.expiresAt, now >= expiresAt else { return }

        if let previousId = preference.previousSessionId,
           let previousTitle = preference.previousSessionTitle {
            let restored = DefaultVoiceSessionPreference(
                sessionId: previousId,
                sessionTitle: previousTitle,
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
            store.save(restored)
            defaultExpiredNotice = .restored(sessionTitle: previousTitle)
            WatchVoiceSessionContextSync.shared.publish(restored)
        } else {
            store.clear()
            defaultExpiredNotice = .cleared
            WatchVoiceSessionContextSync.shared.publish(nil)
        }
    }

    func handleDeletedSession(_ sessionId: String) {
        if activeSessionId == sessionId {
            activeSessionId = nil
        }
        guard let preference = store.load() else { return }
        if preference.sessionId == sessionId {
            if let previousId = preference.previousSessionId,
               let previousTitle = preference.previousSessionTitle {
                let restored = DefaultVoiceSessionPreference(
                    sessionId: previousId,
                    sessionTitle: previousTitle,
                    expiresAt: preference.expiresAt,
                    previousSessionId: nil,
                    previousSessionTitle: nil
                )
                store.save(restored)
            } else {
                store.clear()
            }
            WatchVoiceSessionContextSync.shared.publish(store.load())
        } else if preference.previousSessionId == sessionId {
            let updated = DefaultVoiceSessionPreference(
                sessionId: preference.sessionId,
                sessionTitle: preference.sessionTitle,
                expiresAt: preference.expiresAt,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
            store.save(updated)
            WatchVoiceSessionContextSync.shared.publish(updated)
        }
    }

    /// Target chat for Watch / deep-link “record” when no chat is already open.
    func mainScreenVoiceChatSession(in sessions: [KBSession], now: Date = Date()) -> KBSession? {
        guard activeSessionId == nil else { return nil }
        guard let preference = validDefaultPreference else { return nil }
        return sessions.first { $0.id == preference.sessionId }
    }

    func indicatorLabel(now: Date = Date()) -> String? {
        guard activeSessionId == nil, let preference = validDefaultPreference else { return nil }
        if let remaining = preference.remainingInterval(at: now) {
            let minutes = max(1, Int(ceil(remaining / 60)))
            return "🎙 \(preference.sessionTitle) · \(minutes) min"
        }
        return "🎙 \(preference.sessionTitle)"
    }
}
