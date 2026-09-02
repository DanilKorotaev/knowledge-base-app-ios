import Foundation

/// Logger settings persisted via `UserDefaultsService`.
final class KBLoggerSettings: LoggerSettingsProviderDescription {
    static let shared = KBLoggerSettings()

    static let defaultMaxHTTPBodyLogBytes = 4_096
    static let minMaxHTTPBodyLogBytes = 1_024
    static let maxMaxHTTPBodyLogBytes = 10 * 1024 * 1024

    @UserDefault(key: .loggerDebugConsole, defaultValue: true)
    var isDebugLogger: Bool

    @UserDefault(key: .loggerFileEnabled, defaultValue: true)
    var isFileLoggerEnabled: Bool

    @UserDefault(key: .loggerVerboseNetwork, defaultValue: false)
    var isVerboseLog: Bool

    @UserDefault(key: .loggerTruncateHTTPBodies, defaultValue: true)
    var truncateLargeHTTPBodies: Bool

    @UserDefault(key: .loggerMaxHTTPBodyBytes, defaultValue: KBLoggerSettings.defaultMaxHTTPBodyLogBytes)
    var maxHTTPBodyLogBytes: Int

    private init() {}
}
