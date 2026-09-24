import Foundation

enum BoardsPreferences {
    private static let enabledKey = "kb.boards.enabled"

    /// Default on so existing TestFlight users keep Overview.
    static var isOverviewEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
