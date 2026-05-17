import Foundation
@testable import KnowledgeBaseApp

final class MockLoggerSettings: LoggerSettingsProviderDescription {
    var isDebugLogger = true
    var isFileLoggerEnabled = false
    var isVerboseLog = false
}

final class MockExcludedLoggerTagsProvider: ExcludedLoggerTagsProviderDescription {
    var excludedTags: Set<LoggerTag> = []
}

final class CapturingLogger: Logger {
    private(set) var entries: [(message: String, level: LogLevel, buildLevel: LogBuildLevel)] = []

    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel) {
        guard let message else { return }
        entries.append(("\(message)", level, buildLevel))
    }

    func tag(_ tag: LoggerTag) -> Logger { self }
}
