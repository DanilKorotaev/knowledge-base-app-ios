import Foundation

/// Client-side persistence for per-session KB mode (fallback until API field is present on all responses).
protocol SessionKBModeStoreProtocol: Sendable {
    func load(sessionId: String) -> Bool?
    func save(sessionId: String, useKnowledgeBase: Bool)
    func remove(sessionId: String)
    func prune(validSessionIds: Set<String>)
    func useKnowledgeBase(for session: KBSession) -> Bool
}

final class SessionKBModeStore: SessionKBModeStoreProtocol {
    static let shared = SessionKBModeStore()

    private let userDefaults: UserDefaultsServiceDescription
    private let sharedSuite: UserDefaults?
    private let storageKey: UserDefaultsKey = UserDefaultsKey("kb.sessions.use_knowledge_base")

    init(
        userDefaults: UserDefaultsServiceDescription = UserDefaultsService.shared,
        sharedSuite: UserDefaults? = AppGroupContainer.sharedDefaults
    ) {
        self.userDefaults = userDefaults
        self.sharedSuite = sharedSuite
        AppGroupContainer.migrateUserDefaultsValue(forKey: storageKey.rawValue)
    }

    func load(sessionId: String) -> Bool? {
        dictionary()[sessionId]
    }

    func save(sessionId: String, useKnowledgeBase: Bool) {
        var map = dictionary()
        map[sessionId] = useKnowledgeBase
        persist(map)
    }

    func remove(sessionId: String) {
        var map = dictionary()
        map.removeValue(forKey: sessionId)
        persist(map)
    }

    func prune(validSessionIds: Set<String>) {
        let pruned = dictionary().filter { validSessionIds.contains($0.key) }
        if pruned.count != dictionary().count {
            persist(pruned)
        }
    }

    func useKnowledgeBase(for session: KBSession) -> Bool {
        load(sessionId: session.id) ?? session.useKnowledgeBase
    }

    private func dictionary() -> [String: Bool] {
        if let data = sharedSuite?.data(forKey: storageKey.rawValue)
            ?? (userDefaults.object(forKey: storageKey) as? Data) {
            return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
        }
        return [:]
    }

    private func persist(_ map: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        userDefaults.set(data, forKey: storageKey)
        sharedSuite?.set(data, forKey: storageKey.rawValue)
    }
}

extension KBSession {
    func kbModeSubtitle(store: SessionKBModeStoreProtocol = SessionKBModeStore.shared) -> String {
        store.useKnowledgeBase(for: self)
            ? L10n.string("session.kb_mode_on")
            : L10n.string("session.kb_mode_off")
    }
}
