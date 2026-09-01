import Foundation

/// Apple-style heart-rate zones as percentages of max HR (zone 1 = 50–60%, …, zone 5 = 90–100%).
enum HeartRateZoneCalculator {
    struct TimedSample {
        var bpm: Double
        var durationMinutes: Double
    }

    /// Default age when date of birth is unavailable.
    private static let fallbackAge = 35

    static func estimatedMaxHeartRate(dateOfBirth: Date?, referenceDate: Date = Date()) -> Double {
        guard let dateOfBirth else {
            return Double(220 - fallbackAge)
        }
        let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: referenceDate).year ?? fallbackAge
        let age = max(10, min(years, 100))
        return Double(220 - age)
    }

    static func summarize(
        samples: [TimedSample],
        maxHeartRateBpm: Double
    ) -> WorkoutHeartRateZonesSummary? {
        guard !samples.isEmpty, maxHeartRateBpm > 0 else { return nil }

        let thresholds = zoneThresholds(maxHeartRateBpm: maxHeartRateBpm)
        var minutes = Array(repeating: 0.0, count: 5)

        for sample in samples {
            let fraction = sample.bpm / maxHeartRateBpm
            let zoneIndex = zoneIndex(forFraction: fraction)
            minutes[zoneIndex] += sample.durationMinutes
        }

        let zones: [HeartRateZoneEntry] = thresholds.enumerated().map { index, threshold in
            HeartRateZoneEntry(
                zone: index + 1,
                bpmMin: threshold.min,
                bpmMax: threshold.max,
                minutes: minutes[index]
            )
        }

        return WorkoutHeartRateZonesSummary(maxHeartRateBpm: maxHeartRateBpm, zones: zones)
    }

    private struct Threshold {
        var min: Double?
        var max: Double?
    }

    /// Zone boundaries as absolute BPM (50–60%, 60–70%, … of max HR).
    private static func zoneThresholds(maxHeartRateBpm: Double) -> [Threshold] {
        let percents: [(Double, Double)] = [
            (0.50, 0.60),
            (0.60, 0.70),
            (0.70, 0.80),
            (0.80, 0.90),
            (0.90, 1.00),
        ]
        return percents.enumerated().map { index, pair in
            let lower = maxHeartRateBpm * pair.0
            let upper = maxHeartRateBpm * pair.1
            if index == 0 {
                return Threshold(min: nil, max: upper)
            }
            if index == percents.count - 1 {
                return Threshold(min: lower, max: nil)
            }
            return Threshold(min: lower, max: upper)
        }
    }

    private static func zoneIndex(forFraction fraction: Double) -> Int {
        switch fraction {
        case ..<0.60: return 0
        case ..<0.70: return 1
        case ..<0.80: return 2
        case ..<0.90: return 3
        default: return 4
        }
    }
}
