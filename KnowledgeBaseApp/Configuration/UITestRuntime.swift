import Foundation

/// Launch-time switches for XCUITest (no network, deterministic stubs).
enum UITestRuntime {
    /// Passed by `KnowledgeBaseAppUITests` via `XCUIApplication.launchArguments`.
    static let launchArgument = "-UITesting"
    /// Show login gate even under `-UITesting` (auth UI coverage).
    static let forceLoginGateArgument = "-UITestingForceLoginGate"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var forceLoginGate: Bool {
        ProcessInfo.processInfo.arguments.contains(forceLoginGateArgument)
    }
}
