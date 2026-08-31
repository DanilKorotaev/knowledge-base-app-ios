import Foundation

enum HealthSyncPreferences {
    private static let enabledKey = "kb.health.sync_enabled"

    static var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
