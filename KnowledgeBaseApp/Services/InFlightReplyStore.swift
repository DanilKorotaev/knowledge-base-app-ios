import Foundation

struct InFlightReplyState: Codable, Equatable, Sendable {
    var sessionId: String
    var startedAt: Date
    var partialText: String?
}

protocol InFlightReplyStoreProtocol: Sendable {
    func load(sessionId: String) -> InFlightReplyState?
    func save(_ state: InFlightReplyState)
    func updatePartial(sessionId: String, text: String)
    func clear(sessionId: String)
}

/// Persists that an assistant reply is still expected after SSE drops (background / leave chat).
final class InFlightReplyStore: InFlightReplyStoreProtocol, @unchecked Sendable {
    static let shared = InFlightReplyStore()

    private let lock = NSLock()
    private let userDefaults: UserDefaultsServiceDescription
    private let storageKey = UserDefaultsKey("kb.sessions.in_flight_reply")
    private let maxAge: TimeInterval

    init(
        userDefaults: UserDefaultsServiceDescription = UserDefaultsService.shared,
        maxAge: TimeInterval = 60 * 30
    ) {
        self.userDefaults = userDefaults
        self.maxAge = maxAge
    }

    func load(sessionId: String) -> InFlightReplyState? {
        lock.lock()
        defer { lock.unlock() }
        guard var map = dictionary() else { return nil }
        guard let state = map[sessionId] else { return nil }
        if Date().timeIntervalSince(state.startedAt) > maxAge {
            map.removeValue(forKey: sessionId)
            persist(map)
            return nil
        }
        return state
    }

    func save(_ state: InFlightReplyState) {
        lock.lock()
        defer { lock.unlock() }
        var map = dictionary() ?? [:]
        map[state.sessionId] = state
        persist(map)
    }

    func updatePartial(sessionId: String, text: String) {
        lock.lock()
        defer { lock.unlock() }
        var map = dictionary() ?? [:]
        guard var state = map[sessionId] else { return }
        state.partialText = text
        map[sessionId] = state
        persist(map)
    }

    func clear(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        var map = dictionary() ?? [:]
        map.removeValue(forKey: sessionId)
        persist(map)
    }

    private func dictionary() -> [String: InFlightReplyState]? {
        guard let data = userDefaults.object(forKey: storageKey) as? Data else { return nil }
        return try? JSONDecoder().decode([String: InFlightReplyState].self, from: data)
    }

    private func persist(_ map: [String: InFlightReplyState]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

enum StreamInterruptionClassifier {
    /// Mid-stream / lifecycle drops where the server may still finish the reply.
    /// Do **not** treat "never connected" errors as resumable — those are hard send
    /// failures and must keep the composer draft for retry.
    static func isResumable(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case URLError.cancelled.rawValue,
                 URLError.timedOut.rawValue,
                 URLError.networkConnectionLost.rawValue:
                return true
            default:
                break
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled, .timedOut, .networkConnectionLost:
                return true
            default:
                return false
            }
        }
        return false
    }
}
