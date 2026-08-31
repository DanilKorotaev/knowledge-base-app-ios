import Foundation

/// Persists last successful sync time for UI (local only; server state remains in `sync_state.json`).
enum SyncRunStore {
    private static let lastSuccessKey = "kb.health.last_successful_sync_at"

    static func recordSuccess(at date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastSuccessKey)
    }

    static var lastSuccessfulSyncAt: Date? {
        let t = UserDefaults.standard.double(forKey: lastSuccessKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}
