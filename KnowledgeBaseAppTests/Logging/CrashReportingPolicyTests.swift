@testable import KnowledgeBaseApp
import XCTest

final class CrashReportingPolicyTests: XCTestCase {
    func testReleaseErrorIsMirroredForAnyTag() {
        XCTAssertTrue(
            CrashBreadcrumbPolicy.shouldMirror(tags: [.userDefaultsService], level: .error, buildLevel: .release)
        )
    }

    func testCrashlyticsLoggingToggleBlocksBreadcrumbs() {
        XCTAssertFalse(
            CrashBreadcrumbPolicy.shouldMirror(
                tags: [.network],
                level: .error,
                buildLevel: .release,
                loggingEnabled: false
            )
        )
    }

    func testDebugLinesStayOffCrashlytics() {
        XCTAssertFalse(
            CrashBreadcrumbPolicy.shouldMirror(tags: [.network], level: .info, buildLevel: .debug)
        )
    }

    func testReleaseInfoOnlyForUsefulTags() {
        XCTAssertTrue(
            CrashBreadcrumbPolicy.shouldMirror(tags: [.network, .http], level: .info, buildLevel: .release)
        )
        XCTAssertFalse(
            CrashBreadcrumbPolicy.shouldMirror(tags: [.chat], level: .info, buildLevel: .release)
        )
        XCTAssertFalse(
            CrashBreadcrumbPolicy.shouldMirror(tags: [.userDefaultsService], level: .info, buildLevel: .release)
        )
    }

    func testSanitizerDropsAuthAndTruncates() {
        XCTAssertNil(CrashBreadcrumbPolicy.sanitized("Authorization: Bearer secret"))
        let long = String(repeating: "a", count: 800)
        XCTAssertEqual(CrashBreadcrumbPolicy.sanitized(long)?.count, CrashBreadcrumbPolicy.maxCharacters)
    }

    func testLogHeaderOmitsSecrets() {
        let text = LogFileHeader.text(
            LogFileHeader.Context(
                version: "2.0.15",
                build: "276",
                os: "18.5",
                model: "iPhone17,1",
                locale: "ru_RU",
                timeZone: "Europe/Moscow",
                logSession: "ABC-123",
                authenticated: true
            )
        )
        XCTAssertTrue(text.contains("app started"))
        XCTAssertTrue(text.contains("log_session: ABC-123"))
        XCTAssertTrue(text.contains("authenticated: yes"))
        XCTAssertFalse(text.lowercased().contains("bearer"))
    }

    func testQueueKeepsDistinctSessionsAndDropsOldest() {
        var ids: [String] = []
        ids = CrashLogUploadQueue.enqueue("one", into: ids)
        ids = CrashLogUploadQueue.enqueue("one", into: ids)
        XCTAssertEqual(ids, ["one"])
        for index in 0 ..< 6 {
            ids = CrashLogUploadQueue.enqueue("s\(index)", into: ids)
        }
        XCTAssertEqual(ids.count, CrashLogUploadQueue.maxCount)
        XCTAssertFalse(ids.contains("one"))
        XCTAssertEqual(ids.last, "s5")
    }

    func testMigrationDisablesDebugConsoleOnce() {
        let name = "kb-logger-migration-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        let service = UserDefaultsService(storage: suite)
        service.set(true, forKey: .loggerDebugConsole)
        LoggerDefaultsMigration.apply(defaults: service)
        XCTAssertEqual(service.bool(forKey: .loggerDebugConsole), false)
        let tagKey = UserDefaultsKeyPrefix.loggerTag.appending(LoggerTag.userDefaultsService.rawValue) + ".enabled"
        XCTAssertEqual(service.bool(forKey: tagKey), false)
        service.set(true, forKey: .loggerDebugConsole)
        LoggerDefaultsMigration.apply(defaults: service)
        XCTAssertEqual(service.bool(forKey: .loggerDebugConsole), true)
        suite.removePersistentDomain(forName: name)
    }
}
