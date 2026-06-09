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
        XCTAssertNil(DefaultVoiceSessionTTL.indefinite.expirationDate(from: start))
        XCTAssertNotNil(DefaultVoiceSessionTTL.endOfDay.expirationDate(from: start, calendar: calendar))
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
        XCTAssertEqual(routing.defaultExpiredNotice, "Voice default expired — restored “Inbox”.")
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
        XCTAssertEqual(routing.defaultExpiredNotice, "Voice default expired.")
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
}
