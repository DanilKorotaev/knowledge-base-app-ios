import Foundation

/// Launch-time switches for XCUITest (no network, deterministic stubs).
enum UITestRuntime {
    /// Passed by `KnowledgeBaseAppUITests` via `XCUIApplication.launchArguments`.
    static let launchArgument = "-UITesting"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}
