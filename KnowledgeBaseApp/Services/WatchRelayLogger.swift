import Foundation

enum WatchRelayLogger {
    private static let logger = makeLogger(tag: .watch)

    static func info(_ message: String) {
        logger.log(message, level: .critical, buildLevel: .release)
    }

    static func error(_ message: String) {
        logger.log("ERROR: \(message)", level: .critical, buildLevel: .release)
    }

    static func ingestWatchLine(_ line: String) {
        logger.log("Watch → \(line)", level: .critical, buildLevel: .release)
    }
}
