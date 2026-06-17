import Foundation

enum WatchRelayLogger {
    private static let logger = makeLogger(tag: .watch)

    static func info(_ message: String) {
        logger.log(message, level: .info, buildLevel: .release)
    }

    static func error(_ message: String) {
        logger.log(message, level: .error, buildLevel: .release)
    }

    static func ingestWatchLine(_ line: String) {
        let level: LogLevel = line.contains("ERROR:") ? .error : .info
        logger.log("Watch → \(line)", level: level, buildLevel: .release)
    }
}
