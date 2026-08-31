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

        let asleepDeep = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        let asleepREM = HKCategoryValueSleepAnalysis.asleepREM.rawValue
        let asleepCore = HKCategoryValueSleepAnalysis.asleepCore.rawValue
        let asleepUnspecified = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        let awakeValue = HKCategoryValueSleepAnalysis.awake.rawValue

        for sample in categorySamples {
            let minutes = clippedMinutes(sample: sample, dayStart: dayStart, dayEnd: dayEnd)
            guard minutes > 0 else { continue }
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
                break
            }
        }

        let total = deep + rem + light
        guard total > 0 || awake > 0 else { return nil }
        return SleepSummary(
            totalMinutes: total,
            deepMinutes: deep > 0 ? deep : nil,
            remMinutes: rem > 0 ? rem : nil,
            lightMinutes: light > 0 ? light : nil,
            awakeMinutes: awake > 0 ? awake : nil
        )
    }

    private static func clippedMinutes(sample: HKCategorySample, dayStart: Date, dayEnd: Date) -> Double {
        let start = max(sample.startDate, dayStart)
        let end = min(sample.endDate, dayEnd)
        let seconds = max(0, end.timeIntervalSince(start))
        return seconds / 60.0
    }
}
