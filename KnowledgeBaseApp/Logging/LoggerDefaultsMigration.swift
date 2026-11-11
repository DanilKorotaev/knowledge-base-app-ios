import Foundation

enum LoggerDefaultsMigration {
    static let currentVersion = 1

    static func apply(defaults: UserDefaultsServiceDescription = UserDefaultsService.shared) {
        let stored = defaults.object(forKey: UserDefaultsKey.loggerSettingsVersion) as? Int ?? 0
        guard stored < currentVersion else { return }
        defaults.set(false, forKey: .loggerDebugConsole)
        let tagKey = UserDefaultsKeyPrefix.loggerTag.appending(LoggerTag.userDefaultsService.rawValue) + ".enabled"
        defaults.set(false, forKey: tagKey)
        defaults.set(currentVersion, forKey: .loggerSettingsVersion)
    }
}
