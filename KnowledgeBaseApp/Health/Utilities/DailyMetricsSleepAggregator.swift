import Foundation
import HealthKit

/// Clips sleep category samples to a local calendar day and sums stage minutes.
enum DailyMetricsSleepAggregator {
    static func buildSummary(
        categorySamples: [HKCategorySample],
        dayStart: Date,
        dayEnd: Date
    ) -> SleepSummary? {
        var deep: Double = 0
        var rem: Double = 0
        var light: Double = 0
        var awake: Double = 0
        var segments: [SleepSegment] = []

        let asleepDeep = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        let asleepREM = HKCategoryValueSleepAnalysis.asleepREM.rawValue
        let asleepCore = HKCategoryValueSleepAnalysis.asleepCore.rawValue
        let asleepUnspecified = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        let awakeValue = HKCategoryValueSleepAnalysis.awake.rawValue

        for sample in categorySamples {
            let start = max(sample.startDate, dayStart)
            let end = min(sample.endDate, dayEnd)
            let minutes = clippedMinutes(start: start, end: end)
            guard minutes > 0 else { continue }

            let stage = stageSlug(for: sample.value)
            switch sample.value {
            case asleepDeep:
                deep += minutes
            case asleepREM:
                rem += minutes
            case asleepCore, asleepUnspecified:
                light += minutes
            case awakeValue:
                awake += minutes
            default:
                continue
            }

            segments.append(
                SleepSegment(
                    stage: stage,
                    start: CalendarDayFormatter.iso8601UTCSeconds(from: start),
                    end: CalendarDayFormatter.iso8601UTCSeconds(from: end),
                    minutes: minutes
                )
            )
        }

        segments.sort { $0.start < $1.start }
        let total = deep + rem + light
        guard total > 0 || awake > 0 else { return nil }
        return SleepSummary(
            totalMinutes: total,
            deepMinutes: deep > 0 ? deep : nil,
            remMinutes: rem > 0 ? rem : nil,
            lightMinutes: light > 0 ? light : nil,
            awakeMinutes: awake > 0 ? awake : nil,
            segments: segments.isEmpty ? nil : segments,
            heartRate: nil
        )
    }

    static func sleepWindow(from segments: [SleepSegment]) -> (start: Date, end: Date)? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let starts = segments.compactMap { formatter.date(from: $0.start) }
        let ends = segments.compactMap { formatter.date(from: $0.end) }
        guard let start = starts.min(), let end = ends.max(), end > start else { return nil }
        return (start, end)
    }

    private static func stageSlug(for value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "rem"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "core"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "unspecified"
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
        default: return "unknown"
        }
    }

    private static func clippedMinutes(start: Date, end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / 60.0)
    }
}
