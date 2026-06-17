import Foundation

protocol PinnedSessionsStoreProtocol: Sendable {
    func loadOrderedIds() -> [String]
    func pin(sessionId: String)
    func unpin(sessionId: String)
    func isPinned(_ sessionId: String) -> Bool
    func remove(sessionId: String)
    func prune(validSessionIds: Set<String>)
}

final class PinnedSessionsStore: PinnedSessionsStoreProtocol {
    static let shared = PinnedSessionsStore()

    private let userDefaults: UserDefaultsServiceDescription

    init(userDefaults: UserDefaultsServiceDescription = UserDefaultsService.shared) {
        self.userDefaults = userDefaults
    }

    func loadOrderedIds() -> [String] {
        guard let data = userDefaults.object(forKey: .pinnedSessionIds) as? Data else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func pin(sessionId: String) {
        var ids = loadOrderedIds().filter { $0 != sessionId }
        ids.insert(sessionId, at: 0)
        save(ids)
    }

    func unpin(sessionId: String) {
        let ids = loadOrderedIds().filter { $0 != sessionId }
        save(ids)
    }

    func isPinned(_ sessionId: String) -> Bool {
        loadOrderedIds().contains(sessionId)
    }

    func remove(sessionId: String) {
        unpin(sessionId: sessionId)
    }

    func prune(validSessionIds: Set<String>) {
        let pruned = loadOrderedIds().filter { validSessionIds.contains($0) }
        if pruned != loadOrderedIds() {
            save(pruned)
        }
    }

    private func save(_ ids: [String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        userDefaults.set(data, forKey: .pinnedSessionIds)
    }
}
