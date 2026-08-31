import Foundation
import HealthKit

protocol HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool { get }
    var requiredReadTypes: Set<HKObjectType> { get }
    func requestReadAuthorization() async throws
    /// Fetches quantity aggregates, HR/HRV/SpO₂ samples, and sleep segments for the local calendar day containing `date`.
    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput
    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData
    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData
    /// Incremental workouts via `HKAnchoredObjectQuery`. Pass `nil` anchor for the first run (full history in batches).
    func fetchWorkoutsIncremental(anchor: Data?, limit: Int) async throws -> (workouts: [WorkoutAggregationInput], newAnchor: Data?)
}

enum HealthKitServiceError: Error, Equatable {
    case healthDataUnavailable
    case backgroundDeliveryEnableFailed
}

struct DailyAggregationInput: Equatable {
    var date: String
    var steps: Int
    var distanceKm: Double
    var activeCalories: Double
    var basalCalories: Double
    var exerciseMinutes: Double
    var standHours: Double
    var restingHeartRate: Double?
    var hrvValues: [Double]
    var oxygenSaturationValues: [Double]
    /// Discrete BPM samples for the day (optional); prefer `heartRateSummary` when from HKStatistics.
    var heartRateValues: [Double]
    var heartRateSummary: HeartRateStats?
    var sleep: SleepSummary?
    var syncedAt: String?
}

struct WorkoutAggregationInput: Equatable {
    struct HeartRateSample: Equatable {
        var bpm: Double
        var durationMinutes: Double
    }

    /// `HKWorkout.uuid` string for naming and JSON `source_id`.
    var sourceIdentifier: String
    var date: String
    var workoutType: String
    var workoutTypeDisplay: String
    var isGym: Bool
    var durationMinutes: Double
    var distanceKm: Double?
    var activeCalories: Double?
    var totalCalories: Double?
    var heartRateSamples: [HeartRateSample]
    var linkedNote: String?
    var syncedAt: String?
}

protocol HealthStoreProtocol {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws
}

/// HealthKit APIs needed for background delivery and observer queries (same `HKHealthStore` as reads).
protocol HKBackgroundCapableHealthStore: AnyObject, HealthStoreProtocol {
    func enableBackgroundDelivery(for objectType: HKObjectType, frequency: HKUpdateFrequency) async throws
    func disableBackgroundDelivery(for objectType: HKObjectType) async throws
    func execute(query: HKQuery)
    func stop(query: HKQuery)
}

final class HealthStoreAdapter: HKBackgroundCapableHealthStore {
    static let shared = HealthStoreAdapter()

    private let healthStore = HKHealthStore()

    private init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func enableBackgroundDelivery(for objectType: HKObjectType, frequency: HKUpdateFrequency) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: objectType, frequency: frequency) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitServiceError.backgroundDeliveryEnableFailed)
                }
            }
        }
    }

    func disableBackgroundDelivery(for objectType: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.disableBackgroundDelivery(for: objectType) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitServiceError.backgroundDeliveryEnableFailed)
                }
            }
        }
    }

    func execute(query: HKQuery) {
        healthStore.execute(query)
    }

    func stop(query: HKQuery) {
        healthStore.stop(query)
    }
}

/// Reads samples from HealthKit and manages authorization.
final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore: HealthStoreProtocol
    private let queryStore: DailyHealthKitDataProviding
    private let workoutAnchorStore: WorkoutAnchoredQueryProviding
    private let calendar: Calendar

    init(
        healthStore: HealthStoreProtocol = HealthStoreAdapter.shared,
        queryStore: DailyHealthKitDataProviding? = nil,
        workoutAnchorStore: WorkoutAnchoredQueryProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.healthStore = healthStore
        self.queryStore = queryStore ?? (healthStore as? DailyHealthKitDataProviding) ?? HealthStoreAdapter.shared
        self.workoutAnchorStore = workoutAnchorStore
            ?? (healthStore as? WorkoutAnchoredQueryProviding)
            ?? HealthStoreAdapter.shared
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool {
        healthStore.isHealthDataAvailable
    }

    var requiredReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .appleStandTime),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ]
        .compactMap { $0 }
        .forEach { types.insert($0) }
        return types
    }

    func requestReadAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        try await healthStore.requestAuthorization(toShare: nil, read: requiredReadTypes)
    }

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        let dayKey = CalendarDayFormatter.yyyyMMddLocalDay(containing: date, calendar: calendar)
        let syncedAt = CalendarDayFormatter.iso8601UTCSeconds(from: Date())

        let steps = Int(
            try await cumulativeSum(.stepCount, unit: HKUnit.count(), from: dayStart, to: dayEnd).rounded()
        )
        let distanceMeters = try await cumulativeSum(
            .distanceWalkingRunning,
            unit: HKUnit.meter(),
            from: dayStart,
            to: dayEnd
        )
        let distanceKm = distanceMeters / 1000.0

        let activeCalories = try await cumulativeSum(
            .activeEnergyBurned,
            unit: HKUnit.kilocalorie(),
            from: dayStart,
            to: dayEnd
        )
        let basalCalories = try await cumulativeSum(
            .basalEnergyBurned,
            unit: HKUnit.kilocalorie(),
            from: dayStart,
            to: dayEnd
        )
        let exerciseMinutes = try await cumulativeSum(
            .appleExerciseTime,
            unit: HKUnit.minute(),
            from: dayStart,
            to: dayEnd
        )
        let standHours = try await cumulativeSum(
            .appleStandTime,
            unit: HKUnit.hour(),
            from: dayStart,
            to: dayEnd
        )

        let restingHeartRate = try await discreteAverage(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            from: dayStart,
            to: dayEnd
        )

        let hrvValues = try await hrvSampleValues(from: dayStart, to: dayEnd)
        let oxygenSaturationValues = try await oxygenSamplePercents(from: dayStart, to: dayEnd)
        let heartRateSummary = try await heartRateStatistics(from: dayStart, to: dayEnd)

        let sleep: SleepSummary?
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let sleepQueryStart = calendar.date(byAdding: .hour, value: -14, to: dayStart) ?? dayStart
            let sleepSamples = try await queryStore.categorySamples(
                for: sleepType,
                from: sleepQueryStart,
                to: dayEnd
            )
            sleep = DailyMetricsSleepAggregator.buildSummary(
                categorySamples: sleepSamples,
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        } else {
            sleep = nil
        }

        return DailyAggregationInput(
            date: dayKey,
            steps: steps,
            distanceKm: distanceKm,
            activeCalories: activeCalories,
            basalCalories: basalCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            restingHeartRate: restingHeartRate,
            hrvValues: hrvValues,
            oxygenSaturationValues: oxygenSaturationValues,
            heartRateValues: [],
            heartRateSummary: heartRateSummary,
            sleep: sleep,
            syncedAt: syncedAt
        )
    }

    private func cumulativeSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let stats = try await queryStore.statistics(
            for: type,
            from: start,
            to: end,
            options: [.cumulativeSum]
        )
        return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func discreteAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let stats = try await queryStore.statistics(
            for: type,
            from: start,
            to: end,
            options: [.discreteAverage]
        )
        guard let q = stats?.averageQuantity() else { return nil }
        let v = q.doubleValue(for: unit)
        return v > 0 ? v : nil
    }

    private func hrvSampleValues(from start: Date, to end: Date) async throws -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let ms = HKUnit.secondUnit(with: .milli)
        let samples = try await queryStore.quantitySamples(for: type, from: start, to: end)
        return samples.map { $0.quantity.doubleValue(for: ms) }
    }

    private func oxygenSamplePercents(from start: Date, to end: Date) async throws -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return [] }
        let percent = HKUnit.percent()
        let samples = try await queryStore.quantitySamples(for: type, from: start, to: end)
        return samples.map { Self.spo2FractionToPercent($0.quantity.doubleValue(for: percent)) }
    }

    private static func spo2FractionToPercent(_ value: Double) -> Double {
        if value > 0, value <= 1.0 {
            return value * 100.0
        }
        return value
    }

    private func heartRateStatistics(from start: Date, to end: Date) async throws -> HeartRateStats? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let bpm = HKUnit.count().unitDivided(by: HKUnit.minute())
        let stats = try await queryStore.statistics(
            for: type,
            from: start,
            to: end,
            options: [.discreteMin, .discreteMax, .discreteAverage]
        )
        guard let s = stats else { return nil }
        let minV = s.minimumQuantity()?.doubleValue(for: bpm)
        let maxV = s.maximumQuantity()?.doubleValue(for: bpm)
        let avgV = s.averageQuantity()?.doubleValue(for: bpm)
        guard let minV, let maxV, let avgV else { return nil }
        return HeartRateStats(min: minV, max: maxV, average: avgV)
    }

    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData {
        let heartRateStats: HeartRateStats?
        if let summary = input.heartRateSummary {
            heartRateStats = summary
        } else if !input.heartRateValues.isEmpty {
            heartRateStats = HeartRateStats(
                min: input.heartRateValues.min() ?? 0,
                max: input.heartRateValues.max() ?? 0,
                average: input.heartRateValues.average
            )
        } else {
            heartRateStats = nil
        }

        return DailyHealthData(
            date: input.date,
            steps: input.steps,
            distanceKm: input.distanceKm,
            activeCalories: input.activeCalories,
            basalCalories: input.basalCalories,
            totalCalories: input.activeCalories + input.basalCalories,
            exerciseMinutes: input.exerciseMinutes,
            standHours: input.standHours,
            restingHeartRate: input.restingHeartRate,
            hrvAverage: input.hrvValues.averageOrNil,
            oxygenSaturationAverage: input.oxygenSaturationValues.averageOrNil,
            heartRate: heartRateStats,
            sleep: input.sleep,
            syncedAt: input.syncedAt
        )
    }

    func fetchWorkoutsIncremental(anchor: Data?, limit: Int) async throws -> (
        workouts: [WorkoutAggregationInput],
        newAnchor: Data?
    ) {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        let hkAnchor: HKQueryAnchor?
        if let anchor = anchor {
            hkAnchor = try HKQueryAnchorCoder.decode(anchor)
        } else {
            hkAnchor = nil
        }
        let batchLimit = max(1, limit)
        let (workouts, newAnchor) = try await workoutAnchorStore.fetchWorkouts(anchor: hkAnchor, limit: batchLimit)
        var inputs: [WorkoutAggregationInput] = []
        inputs.reserveCapacity(workouts.count)
        for workout in workouts {
            inputs.append(try await workoutAggregationInput(from: workout))
        }
        let newData = try newAnchor.map { try HKQueryAnchorCoder.encode($0) }
        return (workouts: inputs, newAnchor: newData)
    }

    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData {
        let averageHeartRate = input.heartRateSamples.isEmpty ? nil : input.heartRateSamples.map(\.bpm).average
        let maxHeartRate = input.heartRateSamples.map(\.bpm).max()
        let zones = makeHeartRateZones(from: input.heartRateSamples)

        return WorkoutData(
            sourceIdentifier: input.sourceIdentifier,
            date: input.date,
            workoutType: input.workoutType,
            workoutTypeDisplay: input.workoutTypeDisplay,
            isGym: input.isGym,
            durationMinutes: input.durationMinutes,
            distanceKm: input.distanceKm,
            activeCalories: input.activeCalories,
            totalCalories: input.totalCalories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: zones,
            linkedNote: input.linkedNote,
            syncedAt: input.syncedAt
        )
    }

    private func workoutAggregationInput(from workout: HKWorkout) async throws -> WorkoutAggregationInput {
        let syncedAt = CalendarDayFormatter.iso8601UTCSeconds(from: Date())
        let dayKey = CalendarDayFormatter.yyyyMMddLocalDay(containing: workout.startDate, calendar: calendar)
        let heartRateSamples = try await heartRateSamplesDuringWorkout(workout)
        let distanceKm = workout.totalDistance.map { $0.doubleValue(for: HKUnit.meter()) / 1000.0 }
        let activeCalories = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
        let durationMinutes = workout.duration / 60.0
        return WorkoutAggregationInput(
            sourceIdentifier: workout.uuid.uuidString,
            date: dayKey,
            workoutType: WorkoutTypeSlug.snakeCase(workout.workoutActivityType),
            workoutTypeDisplay: WorkoutTypeSlug.displayName(for: workout.workoutActivityType),
            isGym: Self.isGymStyleWorkout(workout.workoutActivityType),
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            activeCalories: activeCalories,
            totalCalories: activeCalories,
            heartRateSamples: heartRateSamples,
            linkedNote: nil,
            syncedAt: syncedAt
        )
    }

    private func heartRateSamplesDuringWorkout(_ workout: HKWorkout) async throws -> [WorkoutAggregationInput.HeartRateSample] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let samples = try await queryStore.quantitySamples(
            for: hrType,
            from: workout.startDate,
            to: workout.endDate
        )
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var result: [WorkoutAggregationInput.HeartRateSample] = []
        for i in sorted.indices {
            let start = sorted[i].startDate
            let end = i + 1 < sorted.count ? sorted[i + 1].startDate : workout.endDate
            let minutes = max(0, end.timeIntervalSince(start) / 60.0)
            let bpm = sorted[i].quantity.doubleValue(for: bpmUnit)
            result.append(WorkoutAggregationInput.HeartRateSample(bpm: bpm, durationMinutes: minutes))
        }
        return result
    }

    private static func isGymStyleWorkout(_ activity: HKWorkoutActivityType) -> Bool {
        switch activity {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining,
             .crossTraining,
             .flexibility,
             .mixedCardio,
             .highIntensityIntervalTraining:
            return true
        default:
            return false
        }
    }

    private func makeHeartRateZones(from samples: [WorkoutAggregationInput.HeartRateSample]) -> HeartRateZones? {
        guard !samples.isEmpty else { return nil }
        let maxObserved = max(samples.map(\.bpm).max() ?? 0, 1)
        var zone1 = 0.0
        var zone2 = 0.0
        var zone3 = 0.0
        var zone4 = 0.0
        var zone5 = 0.0

        for sample in samples {
            let percent = sample.bpm / maxObserved
            switch percent {
            case ..<0.6:
                zone1 += sample.durationMinutes
            case ..<0.7:
                zone2 += sample.durationMinutes
            case ..<0.8:
                zone3 += sample.durationMinutes
            case ..<0.9:
                zone4 += sample.durationMinutes
            default:
                zone5 += sample.durationMinutes
            }
        }

        return HeartRateZones(
            zone1Below60: zone1,
            zone2From60To70: zone2,
            zone3From70To80: zone3,
            zone4From80To90: zone4,
            zone5Above90: zone5
        )
    }
}

private extension Array where Element == Double {
    var averageOrNil: Double? {
        isEmpty ? nil : average
    }

    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
