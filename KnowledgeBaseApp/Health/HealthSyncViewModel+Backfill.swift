import Foundation

extension HealthSyncViewModel {
    /// Calendar day (yyyy-MM-dd) before which historical daily export should reach.
    var backfillTargetDayKey: String? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let target = calendar.date(
            byAdding: .day,
            value: -KBHealthSyncService.defaultDailyBackfillMaxAgeDays,
            to: todayStart
        ) else {
            return nil
        }
        return CalendarDayFormatter.yyyyMMdd(for: target)
    }

    var workoutsAreOnServer: Bool {
        remoteSyncState?.workoutQueryAnchor != nil
    }

    var isHistoricalBackfillComplete: Bool {
        guard let oldest = remoteSyncState?.dailyBackfillOldestCompleted,
              let target = backfillTargetDayKey else {
            return false
        }
        return oldest <= target
    }

    var estimatedHistoricalDaysRemaining: Int? {
        guard !isHistoricalBackfillComplete,
              let oldest = remoteSyncState?.dailyBackfillOldestCompleted,
              let oldestDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: oldest, calendar: .current),
              let targetKey = backfillTargetDayKey,
              let targetDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: targetKey, calendar: .current) else {
            return nil
        }
        let days = Calendar.current.dateComponents([.day], from: targetDay, to: oldestDay).day ?? 0
        return max(0, days)
    }

    func syncStageFooterText(for phase: Phase) -> String? {
        guard case let .syncing(stage, uploadedCount) = phase else { return nil }
        switch stage {
        case "starting":
            return String(localized: "health.sync.stage.starting")
        case "workouts":
            return String(localized: "health.sync.stage.workouts")
        case "daily":
            return String(localized: "health.sync.stage.daily")
        case "history":
            return String(format: String(localized: "health.sync.stage.history %lld"), Int64(uploadedCount))
        case "archive":
            return String(format: String(localized: "health.sync.stage.archive %lld"), Int64(uploadedCount))
        case "uploading":
            return String(format: String(localized: "health.sync.stage.uploading %lld"), Int64(uploadedCount))
        case "done":
            return String(localized: "health.sync.stage.finishing")
        default:
            return String(localized: "health.sync.running")
        }
    }
}
