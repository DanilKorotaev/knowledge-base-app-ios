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
        guard case let .syncing(stage, uploadedCount, totalCount) = phase else { return nil }
        switch stage {
        case "starting":
            return L10n.string("health.sync.stage.starting")
        case "workouts":
            if uploadedCount > 0 {
                return L10n.format("health.sync.stage.workouts_count %lld", Int64(uploadedCount))
            }
            return L10n.string("health.sync.stage.workouts")
        case "daily":
            return L10n.string("health.sync.stage.daily")
        case "history":
            return L10n.format("health.sync.stage.history %lld", Int64(uploadedCount))
        case "archive":
            return L10n.format("health.sync.stage.archive %lld", Int64(uploadedCount))
        case "uploading":
            if let totalCount, totalCount > 0 {
                let percent = Int((Double(uploadedCount) / Double(totalCount) * 100).rounded())
                return L10n.format(
                    "health.sync.stage.uploading_progress %lld %lld %lld",
                    Int64(uploadedCount),
                    Int64(totalCount),
                    Int64(percent)
                )
            }
            return L10n.format("health.sync.stage.uploading %lld", Int64(uploadedCount))
        case "done":
            return L10n.string("health.sync.stage.finishing")
        default:
            return L10n.string("health.sync.running")
        }
    }
}
