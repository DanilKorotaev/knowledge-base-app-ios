import XCTest
@testable import KnowledgeBaseApp

final class LoggerTests: XCTestCase {
    func testLogLevelDescriptionAndEmoji() {
        XCTAssertEqual(LogLevel.info.description, "INFO")
        XCTAssertEqual(LogLevel.warning.emoji, "⚠️")
        XCTAssertEqual(LogLevel.critical.emoji, "❌")
    }

    func testMakeLoggerWritesWhenDebugEnabled() {
        let settings = MockLoggerSettings()
        settings.isDebugLogger = true
        settings.isFileLoggerEnabled = false
        let config = LoggerConfig(
            excludedTagProvider: MockExcludedLoggerTagsProvider(),
            settings: settings
        )
        let logger = makeLogger(tags: [.network, .http], config: config)
        logger.debugInfo("hello")
        logger.warning("careful")
        logger.releaseInfo("ship")
        logger.releaseError(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
    }

    func testExcludedTagSuppressesDebugLogs() {
        let settings = MockLoggerSettings()
        settings.isDebugLogger = true
        let excluded = MockExcludedLoggerTagsProvider()
        excluded.excludedTags = [.network]
        let config = LoggerConfig(excludedTagProvider: excluded, settings: settings)
        let logger = makeLogger(tag: .network, config: config)
        logger.debugInfo("hidden")
    }

    func testCriticalLogsWhenTagExcluded() {
        let settings = MockLoggerSettings()
        settings.isDebugLogger = false
        let excluded = MockExcludedLoggerTagsProvider()
        excluded.excludedTags = [.network]
        let config = LoggerConfig(excludedTagProvider: excluded, settings: settings)
        let logger = makeLogger(tag: .network, config: config)
        logger.log("critical path", level: .critical, buildLevel: .debug)
        logger.log("non-fatal path", level: .nonFatal, buildLevel: .debug)
    }

    func testTagChaining() {
        let settings = MockLoggerSettings()
        settings.isFileLoggerEnabled = false
        let config = LoggerConfig(
            excludedTagProvider: MockExcludedLoggerTagsProvider(),
            settings: settings
        )
        let tagged = makeLogger(tag: .chat, config: config).tag(.files)
        tagged.debugInfo("nested tags")
    }
}
