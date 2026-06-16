import Foundation

/// Cross-platform Watch relay diagnostics. iPhone persists via `Logger`; Watch forwards lines over WCSession.
enum WatchRelayLog {
    static var forwardToPhone: (@Sendable (String) -> Void)?

    static func info(_ message: String) {
        let line = formatted(message)
        #if os(watchOS)
        forwardToPhone?(line)
        #endif
        localSink?(line)
    }

    static func error(_ message: String) {
        info("ERROR: \(message)")
    }

    /// Platform-specific sink (FileLogger on iPhone, optional console on Watch).
    static var localSink: (@Sendable (String) -> Void)?

    private static func formatted(_ message: String) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date())
        return "[\(stamp)] \(message)"
    }
}
