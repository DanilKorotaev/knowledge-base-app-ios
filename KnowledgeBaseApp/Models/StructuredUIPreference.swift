import Foundation

/// Global preference: agent may attach Interactive UI to chat replies (and panels stay interactive).
enum StructuredUIPreference {
    static let headerName = "X-KB-Structured-UI"

    /// Default **on** when the key was never set.
    static var isEnabled: Bool {
        get {
            if UserDefaultsService.shared.object(forKey: .structuredUIEnabled) == nil {
                return true
            }
            return UserDefaultsService.shared.bool(forKey: .structuredUIEnabled)
        }
        set {
            UserDefaultsService.shared.set(newValue, forKey: .structuredUIEnabled)
        }
    }

    static var headerValue: String { isEnabled ? "1" : "0" }
}
