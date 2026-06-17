import XCTest
@testable import KnowledgeBaseApp

final class VoiceSessionTargetResolverTests: XCTestCase {
    func testPrefersActiveSession() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: "chat",
            defaultPreference: DefaultVoiceSessionPreference(
                sessionId: "default",
                sessionTitle: "Default",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            ),
            orderedSessionIds: ["default", "chat", "other"]
        )
        XCTAssertEqual(result, "chat")
    }

    func testUsesValidDefaultWhenNoActiveChat() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: nil,
            defaultPreference: DefaultVoiceSessionPreference(
                sessionId: "inbox",
                sessionTitle: "Inbox",
                expiresAt: Date().addingTimeInterval(3600),
                previousSessionId: nil,
                previousSessionTitle: nil
            ),
            orderedSessionIds: ["other", "inbox"]
        )
        XCTAssertEqual(result, "inbox")
    }

    func testSkipsExpiredDefault() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: nil,
            defaultPreference: DefaultVoiceSessionPreference(
                sessionId: "wonder",
                sessionTitle: "Wonder",
                expiresAt: Date().addingTimeInterval(-60),
                previousSessionId: nil,
                previousSessionTitle: nil
            ),
            orderedSessionIds: ["first", "second"],
            now: Date()
        )
        XCTAssertEqual(result, "first")
    }

    func testFallsBackToFirstSession() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: nil,
            defaultPreference: nil,
            orderedSessionIds: ["alpha", "beta"]
        )
        XCTAssertEqual(result, "alpha")
    }

    func testSkipsActiveSessionWhenNotInList() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: "missing",
            defaultPreference: DefaultVoiceSessionPreference(
                sessionId: "inbox",
                sessionTitle: "Inbox",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            ),
            orderedSessionIds: ["inbox", "other"]
        )
        XCTAssertEqual(result, "inbox")
    }

    func testSkipsExpiredDefaultWhenNoActiveChat() {
        let result = VoiceSessionTargetResolver.resolve(
            activeSessionId: nil,
            defaultPreference: DefaultVoiceSessionPreference(
                sessionId: "expired",
                sessionTitle: "Expired",
                expiresAt: Date().addingTimeInterval(-30),
                previousSessionId: nil,
                previousSessionTitle: nil
            ),
            orderedSessionIds: ["first", "second"],
            now: Date()
        )
        XCTAssertEqual(result, "first")
    }
}

final class DefaultVoiceSessionPreferenceTests: XCTestCase {
    func testTTLExpirationDates() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(
            DefaultVoiceSessionTTL.oneHour.expirationDate(from: start)?.timeIntervalSince1970,
            start.addingTimeInterval(3600).timeIntervalSince1970
        )
        XCTAssertEqual(
            DefaultVoiceSessionTTL.thirtyMinutes.expirationDate(from: start)?.timeIntervalSince1970,
            start.addingTimeInterval(1800).timeIntervalSince1970
        )
        XCTAssertEqual(
            DefaultVoiceSessionTTL.twoHours.expirationDate(from: start)?.timeIntervalSince1970,
            start.addingTimeInterval(7200).timeIntervalSince1970
        )
        XCTAssertNil(DefaultVoiceSessionTTL.indefinite.expirationDate(from: start))
        XCTAssertNotNil(DefaultVoiceSessionTTL.endOfDay.expirationDate(from: start, calendar: calendar))
        XCTAssertEqual(DefaultVoiceSessionTTL.thirtyMinutes.label, "30 minutes")
        XCTAssertEqual(DefaultVoiceSessionTTL.twoHours.label, "2 hours")
    }

    func testPreferenceValidityAndRemainingInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let valid = DefaultVoiceSessionPreference(
            sessionId: "a",
            sessionTitle: "A",
            expiresAt: now.addingTimeInterval(120),
            previousSessionId: nil,
            previousSessionTitle: nil
        )
        XCTAssertTrue(valid.isValid(at: now))
        XCTAssertFalse(valid.isValid(at: now.addingTimeInterval(200)))
        XCTAssertEqual(valid.remainingInterval(at: now) ?? -1, 120, accuracy: 0.001)

        let indefinite = DefaultVoiceSessionPreference(
            sessionId: "b",
            sessionTitle: "B",
            expiresAt: nil,
            previousSessionId: nil,
            previousSessionTitle: nil
        )
        XCTAssertTrue(indefinite.isValid())
        XCTAssertNil(indefinite.remainingInterval())
    }
}

@MainActor
final class VoiceRoutingContextTests: XCTestCase {
    private final class InMemoryVoiceDefaultStore: DefaultVoiceSessionStoreProtocol {
        var preference: DefaultVoiceSessionPreference?

        func load() -> DefaultVoiceSessionPreference? { preference }
        func save(_ preference: DefaultVoiceSessionPreference) { self.preference = preference }
        func clear() { preference = nil }
    }

    func testExpiryRestoresPreviousDefault() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        let expired = Date().addingTimeInterval(-30)

        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "temp",
                sessionTitle: "Wonder",
                expiresAt: expired,
                previousSessionId: "inbox",
                previousSessionTitle: "Inbox"
            )
        )

        routing.refreshExpiryIfNeeded(now: Date())

        XCTAssertEqual(store.load()?.sessionId, "inbox")
        XCTAssertNil(store.load()?.expiresAt)
        XCTAssertEqual(routing.defaultExpiredNotice, .restored(sessionTitle: "Inbox"))
    }

    func testExpiryClearsWhenNoPrevious() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)

        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "temp",
                sessionTitle: "Temp",
                expiresAt: Date().addingTimeInterval(-10),
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        routing.refreshExpiryIfNeeded(now: Date())

        XCTAssertNil(store.load())
        XCTAssertEqual(routing.defaultExpiredNotice, .cleared)
    }

    func testDismissDefaultExpiredNotice() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)

        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "temp",
                sessionTitle: "Temp",
                expiresAt: Date().addingTimeInterval(-10),
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )
        routing.refreshExpiryIfNeeded(now: Date())
        XCTAssertEqual(routing.defaultExpiredNotice, .cleared)

        routing.dismissDefaultExpiredNotice()
        XCTAssertNil(routing.defaultExpiredNotice)
    }

    func testMainScreenVoiceChatSessionRequiresValidDefault() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        let sessions = [
            KBSession(id: "inbox", title: "Inbox", messageCount: 0, updatedAt: nil),
            KBSession(id: "other", title: "Other", messageCount: 0, updatedAt: nil),
        ]

        XCTAssertNil(routing.mainScreenVoiceChatSession(in: sessions))

        routing.setDefaultVoiceSession(sessions[0], ttl: .indefinite)
        XCTAssertEqual(routing.mainScreenVoiceChatSession(in: sessions)?.id, "inbox")

        routing.activeSessionId = "other"
        XCTAssertNil(routing.mainScreenVoiceChatSession(in: sessions))
    }

    func testSetDefaultPreservesPreviousSession() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)

        routing.setDefaultVoiceSession(
            KBSession(id: "inbox", title: "Inbox", messageCount: 0, updatedAt: nil),
            ttl: .indefinite
        )
        routing.setDefaultVoiceSession(
            KBSession(id: "wonder", title: "Wonder", messageCount: 0, updatedAt: nil),
            ttl: .oneHour
        )

        XCTAssertEqual(store.load()?.sessionId, "wonder")
        XCTAssertEqual(store.load()?.previousSessionId, "inbox")
    }

    func testClearDefaultVoiceSession() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        routing.setDefaultVoiceSession(
            KBSession(id: "inbox", title: "Inbox", messageCount: 0, updatedAt: nil),
            ttl: .indefinite
        )

        routing.clearDefaultVoiceSession()

        XCTAssertNil(store.load())
        XCTAssertNil(routing.defaultExpiredNotice)
    }

    func testResolveVoiceTargetSessionPrefersActiveChat() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        routing.activeSessionId = "chat"
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "default",
                sessionTitle: "Default",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )
        let sessions = [
            KBSession(id: "default", title: "Default", messageCount: 0, updatedAt: nil),
            KBSession(id: "chat", title: "Chat", messageCount: 0, updatedAt: nil),
        ]

        XCTAssertEqual(routing.resolveVoiceTargetSessionId(in: sessions), "chat")
        XCTAssertEqual(routing.resolveVoiceTargetSession(in: sessions)?.title, "Chat")
    }

    func testIsDefaultVoiceSession() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        routing.setDefaultVoiceSession(
            KBSession(id: "125", title: "Session 125", messageCount: 0, updatedAt: nil),
            ttl: .indefinite
        )

        XCTAssertTrue(routing.isDefaultVoiceSession("125"))
        XCTAssertFalse(routing.isDefaultVoiceSession("999"))
    }

    func testIndicatorLabel_withAndWithoutTTL() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        let anchor = Date()

        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "125",
                sessionTitle: "Session 125",
                expiresAt: anchor.addingTimeInterval(90),
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )
        XCTAssertEqual(routing.indicatorLabel(now: anchor), "🎙 Session 125 · 2 min")

        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "inbox",
                sessionTitle: "Inbox",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )
        XCTAssertEqual(routing.indicatorLabel(now: anchor), "🎙 Inbox")
    }

    func testHandleDeletedSession_restoresPreviousDefault() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "wonder",
                sessionTitle: "Wonder",
                expiresAt: nil,
                previousSessionId: "inbox",
                previousSessionTitle: "Inbox"
            )
        )

        routing.handleDeletedSession("wonder")

        XCTAssertEqual(store.load()?.sessionId, "inbox")
        XCTAssertNil(store.load()?.previousSessionId)
    }

    func testHandleDeletedSession_clearsPreviousPointer() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "wonder",
                sessionTitle: "Wonder",
                expiresAt: nil,
                previousSessionId: "inbox",
                previousSessionTitle: "Inbox"
            )
        )

        routing.handleDeletedSession("inbox")

        XCTAssertEqual(store.load()?.sessionId, "wonder")
        XCTAssertNil(store.load()?.previousSessionId)
    }

    func testHandleDeletedSession_clearsActiveSession() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        routing.activeSessionId = "gone"

        routing.handleDeletedSession("gone")

        XCTAssertNil(routing.activeSessionId)
    }

    func testHandleDeletedSession_clearsDefaultWithoutPrevious() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "solo",
                sessionTitle: "Solo",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        routing.handleDeletedSession("solo")

        XCTAssertNil(store.load())
    }

    func testHandleDeletedSession_ignoresUnrelatedSession() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "keep",
                sessionTitle: "Keep",
                expiresAt: nil,
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        routing.handleDeletedSession("other")

        XCTAssertEqual(store.load()?.sessionId, "keep")
    }

    func testRefreshExpiryIfNeeded_noOpWhenStillValid() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "live",
                sessionTitle: "Live",
                expiresAt: Date().addingTimeInterval(3600),
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        routing.refreshExpiryIfNeeded(now: Date())

        XCTAssertEqual(store.load()?.sessionId, "live")
        XCTAssertNil(routing.defaultExpiredNotice)
    }

    func testValidDefaultPreference_nilWhenExpired() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)
        store.save(
            DefaultVoiceSessionPreference(
                sessionId: "expired",
                sessionTitle: "Expired",
                expiresAt: Date().addingTimeInterval(-60),
                previousSessionId: nil,
                previousSessionTitle: nil
            )
        )

        XCTAssertNil(routing.validDefaultPreference)
    }

    func testRefreshExpiryIfNeeded_withoutStoredPreference() {
        let store = InMemoryVoiceDefaultStore()
        let routing = VoiceRoutingContext(store: store)

        routing.refreshExpiryIfNeeded(now: Date())

        XCTAssertNil(store.load())
        XCTAssertNil(routing.defaultExpiredNotice)
    }
}
