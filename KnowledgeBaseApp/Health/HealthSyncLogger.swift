import Foundation

enum HealthSyncLogger {
    private static let logger = makeLogger(tag: .health)

    static func historyStarted(from: String, to: String, resumeFrom: String?, totalDays: Int) {
        logger.releaseInfo(
            "[health-sync] history START from=\(from) to=\(to) resume=\(resumeFrom ?? "nil") days=\(totalDays)"
        )
    }

    static func batchUploaded(days: Int, uploaded: Int, total: Int, oldest: String?) {
        logger.releaseInfo(
            "[health-sync] batch uploaded=\(uploaded)/\(total) batchDays=\(days) oldest=\(oldest ?? "nil")"
        )
    }

    static func historyFinished(uploaded: Int, total: Int, oldest: String?) {
        logger.releaseInfo(
            "[health-sync] history DONE uploaded=\(uploaded)/\(total) oldest=\(oldest ?? "nil")"
        )
    }

    static func historyFailed(_ message: String) {
        logger.releaseError("[health-sync] history FAILED: \(message)")
    }

    static func historyCancelled() {
        logger.releaseInfo("[health-sync] history CANCELLED")
    }
}
