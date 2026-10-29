import Foundation

/// Remembers recently used KB App API base URLs for faster re-login after logout.
enum ServerURLHistoryStore {
    static let maxItems = 8

    /// Last successful / configured URL first, then older history (deduped).
    static func suggestions() -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        func append(_ raw: String?) {
            guard let normalized = normalize(raw), seen.insert(normalized.lowercased()).inserted else { return }
            ordered.append(normalized)
        }
        append(AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL))
        for item in loadRaw() {
            append(item)
        }
        return ordered
    }

    /// Prefill for the server step after logout / cold open on login gate.
    static func preferredPrefill() -> String? {
        suggestions().first
    }

    static func remember(url: URL) {
        remember(url.absoluteString)
    }

    static func remember(_ raw: String) {
        guard let normalized = normalize(raw) else { return }
        var list = loadRaw().filter { $0.caseInsensitiveCompare(normalized) != .orderedSame }
        list.insert(normalized, at: 0)
        if list.count > maxItems {
            list = Array(list.prefix(maxItems))
        }
        UserDefaultsService.shared.set(list, forKey: .serverURLHistory)
        // Keep App Group in sync for extensions that may show the same host later.
        AppGroupContainer.sharedDefaults?.set(list, forKey: UserDefaultsKey.serverURLHistory.rawValue)
    }

    static func clear() {
        UserDefaultsService.shared.removeObject(forKey: .serverURLHistory)
        AppGroupContainer.sharedDefaults?.removeObject(forKey: UserDefaultsKey.serverURLHistory.rawValue)
    }

    // MARK: - Internals

    private static func loadRaw() -> [String] {
        AppGroupContainer.migrateUserDefaultsValue(forKey: UserDefaultsKey.serverURLHistory.rawValue)
        if let shared = AppGroupContainer.sharedDefaults?.stringArray(forKey: UserDefaultsKey.serverURLHistory.rawValue),
           !shared.isEmpty {
            return shared
        }
        return UserDefaultsService.shared.object(forKey: .serverURLHistory) as? [String] ?? []
    }

    private static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        return ServerProbe.normalizeBaseURL(raw)?.absoluteString
    }
}
