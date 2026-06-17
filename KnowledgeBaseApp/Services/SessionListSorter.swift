import Foundation

enum SessionListSorter {
    /// Pinned sessions first (LIFO pin order), then unpinned in API order.
    static func displayOrder(sessions: [KBSession], pinnedIds: [String]) -> [KBSession] {
        guard !pinnedIds.isEmpty else { return sessions }

        let pinnedSet = Set(pinnedIds)
        let pinned = pinnedIds.compactMap { id in sessions.first { $0.id == id } }
        let unpinned = sessions.filter { !pinnedSet.contains($0.id) }
        return pinned + unpinned
    }
}
