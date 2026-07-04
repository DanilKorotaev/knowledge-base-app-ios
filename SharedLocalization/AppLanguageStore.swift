import Foundation
import Observation

public enum AppLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case russian = "ru"

    public var id: String { rawValue }

    public var storageValue: String? {
        switch self {
        case .system: return nil
        case .english, .russian: return rawValue
        }
    }

    public static func from(storageValue: String?) -> AppLanguagePreference {
        guard let storageValue else { return .system }
        return AppLanguagePreference(rawValue: storageValue) ?? .system
    }
}

@Observable
public final class AppLanguageStore {
    public static let shared = AppLanguageStore()
    public static let overrideKey = "kb.app.language_override"

    public private(set) var override: AppLanguagePreference

    private init() {
        override = Self.readOverride(from: .standard)
    }

    public var resolvedLocale: Locale {
        switch override {
        case .system:
            return Locale.autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .russian:
            return Locale(identifier: "ru")
        }
    }

    public var resolvedLanguageCode: String {
        switch override {
        case .system:
            return Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
        case .english:
            return "en"
        case .russian:
            return "ru"
        }
    }

    public func setOverride(_ preference: AppLanguagePreference) {
        override = preference
        let defaults = UserDefaults.standard
        if let value = preference.storageValue {
            defaults.set(value, forKey: Self.overrideKey)
        } else {
            defaults.removeObject(forKey: Self.overrideKey)
        }
    }

    public static func resolvedLocale(from defaults: UserDefaults? = nil) -> Locale {
        _ = defaults
        return AppLanguageStore.shared.resolvedLocale
    }

    private static func readOverride(from defaults: UserDefaults) -> AppLanguagePreference {
        AppLanguagePreference.from(storageValue: defaults.string(forKey: overrideKey))
    }

    #if DEBUG
    public func resetForTesting() {
        setOverride(.system)
    }
    #endif
}
