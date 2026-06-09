import Foundation

protocol LoggerTagsProviderDescription: AnyObject {
    var tags: [LoggerTag] { get }
    func set(isEnabled: Bool, for tag: LoggerTag)
    func setAll(isEnabled: Bool)
    func resetToDefaults()
    func isEnabled(tag: LoggerTag) -> Bool
}

final class KBLoggerTagsProvider: LoggerTagsProviderDescription, ExcludedLoggerTagsProviderDescription {
    static let shared = KBLoggerTagsProvider()

    let tags: [LoggerTag]
    private(set) var excludedTags: Set<LoggerTag> = []

    private static let allTags: [LoggerTag] = [
        .common, .network, .http, .sessions, .chat, .files, .voice, .config, .debug, .userDefaultsService,
    ]

    /// Tags off on first launch; enable in Debug → Log settings when needed.
    private static let disabledByDefault: Set<LoggerTag> = [.chat]

    private init() {
        tags = Self.allTags
        excludedTags = Set(tags.filter { !isEnabled(tag: $0) })
    }

    func set(isEnabled: Bool, for tag: LoggerTag) {
        UserDefaultsService.shared.set(isEnabled, forKey: storageKey(for: tag))
        if isEnabled {
            excludedTags.remove(tag)
        } else {
            excludedTags.insert(tag)
        }
    }

    func setAll(isEnabled: Bool) {
        tags.forEach { set(isEnabled: isEnabled, for: $0) }
    }

    func resetToDefaults() {
        tags.forEach { set(isEnabled: Self.isEnabledByDefault(tag: $0), for: $0) }
    }

    func isEnabled(tag: LoggerTag) -> Bool {
        if UserDefaultsService.shared.object(forKey: storageKey(for: tag)) == nil {
            return Self.isEnabledByDefault(tag: tag)
        }
        return UserDefaultsService.shared.bool(forKey: storageKey(for: tag))
    }

    private static func isEnabledByDefault(tag: LoggerTag) -> Bool {
        !disabledByDefault.contains(tag)
    }

    private func storageKey(for tag: LoggerTag) -> String {
        UserDefaultsKeyPrefix.loggerTag.appending(tag.rawValue) + ".enabled"
    }
}
