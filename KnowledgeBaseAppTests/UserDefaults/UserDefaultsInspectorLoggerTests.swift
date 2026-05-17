import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsInspectorLoggerTests: XCTestCase {
    func testStartHandlesUserDefaultsServiceNotification() {
        UserDefaultsInspectorLogger.shared.start()

        let event = UserDefaultsServiceEvent(
            operation: .set,
            key: "kb.logger.test",
            value: "value",
            isWrite: true,
            isIgnored: false
        )
        NotificationCenter.default.post(
            name: .userDefaultsServiceDidHandleOperation,
            object: nil,
            userInfo: ["event": event]
        )

        let expectation = expectation(description: "async log")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
