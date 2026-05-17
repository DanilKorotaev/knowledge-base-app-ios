import XCTest
@testable import KnowledgeBaseApp

final class ConsoleLoggerTests: XCTestCase {
    func testLogsStringMessage() {
        let logger = ConsoleLogger()
        logger.log("plain message", level: .info, buildLevel: .debug)
    }

    func testLogsNSErrorWithDetails() {
        let logger = ConsoleLogger()
        let error = NSError(
            domain: "test",
            code: 42,
            userInfo: [
                NSLocalizedDescriptionKey: "failed",
                NSLocalizedFailureReasonErrorKey: "reason",
                NSLocalizedRecoverySuggestionErrorKey: "retry",
            ]
        )
        logger.log(error, level: .error, buildLevel: .release)
    }
}
