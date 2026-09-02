import Foundation

protocol LoggerSettingsProviderDescription: AnyObject {
    var isDebugLogger: Bool { get }
    var isFileLoggerEnabled: Bool { get }
    var isVerboseLog: Bool { get }
    /// When true, large HTTP request/response bodies are truncated in verbose logs.
    var truncateLargeHTTPBodies: Bool { get }
    /// Max bytes of HTTP body kept in verbose logs when truncation is enabled.
    var maxHTTPBodyLogBytes: Int { get }
}

protocol ExcludedLoggerTagsProviderDescription: AnyObject {
    var excludedTags: Set<LoggerTag> { get }
}

struct LoggerConfig {
    let excludedTagProvider: ExcludedLoggerTagsProviderDescription
    let settings: LoggerSettingsProviderDescription

    init(
        excludedTagProvider: ExcludedLoggerTagsProviderDescription,
        settings: LoggerSettingsProviderDescription
    ) {
        self.excludedTagProvider = excludedTagProvider
        self.settings = settings
    }
}

extension LoggerConfig {
    static let shared = LoggerConfig(
        excludedTagProvider: KBLoggerTagsProvider.shared,
        settings: KBLoggerSettings.shared
    )
}
