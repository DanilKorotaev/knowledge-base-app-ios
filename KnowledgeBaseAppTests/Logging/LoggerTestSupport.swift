import Foundation
@testable import KnowledgeBaseApp

final class MockLoggerSettings: LoggerSettingsProviderDescription {
    var isDebugLogger = true
    var isFileLoggerEnabled = false
    var isVerboseLog = false
    var truncateLargeHTTPBodies = true
    var maxHTTPBodyLogBytes = 4_096
}

final class MockExcludedLoggerTagsProvider: ExcludedLoggerTagsProviderDescription {
    var excludedTags: Set<LoggerTag> = []
}

struct CapturedLogEntry {
    let message: String
    let level: LogLevel
    let buildLevel: LogBuildLevel
}

final class CapturingLogger: Logger {
    private(set) var entries: [CapturedLogEntry] = []

    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel) {
        guard let message else { return }
        entries.append(CapturedLogEntry(message: "\(message)", level: level, buildLevel: buildLevel))
    }

    func tag(_ tag: LoggerTag) -> Logger { self }
}
