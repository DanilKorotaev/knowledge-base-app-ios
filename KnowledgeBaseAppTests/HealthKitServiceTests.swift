import HealthKit
import Testing
@testable import KnowledgeBaseApp

@Suite("HealthKitService")
struct HealthKitServiceTests {
    @Test("required read types include core HealthKit identifiers")
    func requiredReadTypesContainsCoreIdentifiers() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        #expect(sut.requiredReadTypes.contains(HKObjectType.workoutType()))
        #expect(sut.requiredReadTypes.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        #expect(sut.requiredReadTypes.contains(HKObjectType.quantityType(forIdentifier: .stepCount)!))
    }

    @Test("requestReadAuthorization throws when Health data unavailable")
    func requestReadAuthorizationThrowsWhenUnavailable() async {
        let sut = HealthKitService(healthStore: HealthStoreMock(isHealthDataAvailable: false))
        await #expect(throws: HealthKitServiceError.healthDataUnavailable) {
            try await sut.requestReadAuthorization()
        }
    }

    @Test("dailyAggregationInput uses local calendar day key")
    func dailyAggregationInputUsesLocalCalendarDayKey() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let sut = HealthKitService(healthStore: HealthStoreMock(), calendar: utc)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = try #require(formatter.date(from: "2026-04-10T15:00:00Z"))
        let input = try await sut.dailyAggregationInput(for: date)
        #expect(input.date == "2026-04-10")
        #expect(input.syncedAt != nil)
    }

    @Test("makeDailyHealthData prefers heart rate summary over samples")
    func makeDailyHealthDataPrefersHeartRateSummary() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let input = DailyAggregationInput(
            date: "2026-03-30",
            steps: 8000,
            distanceKm: 6.1,
            activeCalories: 450,
            basalCalories: 1600,
            exerciseMinutes: 70,
            standHours: 12,
            restingHeartRate: 58,
            hrvValues: [40, 50],
            oxygenSaturationValues: [96, 98],
            heartRateValues: [40, 200],
            heartRateSummary: HeartRateStats(min: 60, max: 120, average: 90),
            sleep: SleepSummary(totalMinutes: 420, deepMinutes: 90, remMinutes: 100, lightMinutes: 180, awakeMinutes: 50),
            syncedAt: "2026-03-30T10:00:00Z"
        )
        let result = sut.makeDailyHealthData(from: input)
        #expect(result.heartRate?.min == 60)
        #expect(result.heartRate?.max == 120)
        #expect(result.heartRate?.average == 90)
    }

    @Test("makeDailyHealthData calculates derived fields from samples")
    func makeDailyHealthDataCalculatesDerivedFields() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let input = DailyAggregationInput(
            date: "2026-03-30",
            steps: 8000,
            distanceKm: 6.1,
            activeCalories: 450,
            basalCalories: 1600,
            exerciseMinutes: 70,
            standHours: 12,
            restingHeartRate: 58,
            hrvValues: [40, 50],
            oxygenSaturationValues: [96, 98],
            heartRateValues: [60, 90, 120],
            heartRateSummary: nil,
            sleep: SleepSummary(totalMinutes: 420, deepMinutes: 90, remMinutes: 100, lightMinutes: 180, awakeMinutes: 50),
            syncedAt: "2026-03-30T10:00:00Z"
        )
        let result = sut.makeDailyHealthData(from: input)
        #expect(result.totalCalories == 2050)
        #expect(result.hrvAverage == 45)
        #expect(result.oxygenSaturationAverage == 97)
        #expect(result.heartRate?.average == 90)
    }

    @Test("makeWorkoutData calculates heart rate zones")
    func makeWorkoutDataCalculatesHeartRateAndZones() {
        let sut = HealthKitService(healthStore: HealthStoreMock())
        let input = WorkoutAggregationInput(
            sourceIdentifier: "00000000-0000-0000-0000-000000000001",
            date: "2026-03-30",
            workoutType: "traditional_strength_training",
            workoutTypeDisplay: "Strength",
            isGym: true,
            durationMinutes: 60,
            distanceKm: nil,
            activeCalories: 300,
            totalCalories: 420,
            heartRateSamples: [
                .init(bpm: 90, durationMinutes: 10),
                .init(bpm: 105, durationMinutes: 15),
                .init(bpm: 120, durationMinutes: 20),
                .init(bpm: 135, durationMinutes: 10),
                .init(bpm: 150, durationMinutes: 5),
            ],
            linkedNote: nil,
            syncedAt: "2026-03-30T10:00:00Z"
        )
        let result = sut.makeWorkoutData(from: input)
        #expect(result.averageHeartRate == 120)
        #expect(result.maxHeartRate == 150)
        #expect(result.heartRateZones?.zone2From60To70 == 10)
        #expect(result.heartRateZones?.zone5Above90 == 15)
    }
}

private final class HealthStoreMock: HealthStoreProtocol, DailyHealthKitDataProviding {
    private let available: Bool
    private(set) var requestAuthorizationCallCount = 0

    init(isHealthDataAvailable: Bool = true) {
        self.available = isHealthDataAvailable
    }

    var isHealthDataAvailable: Bool { available }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        requestAuthorizationCallCount += 1
    }

    func statistics(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? { nil }

    func quantitySamples(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date
    ) async throws -> [HKQuantitySample] { [] }

    func categorySamples(
        for categoryType: HKCategoryType,
        from start: Date,
        to end: Date
    ) async throws -> [HKCategorySample] { [] }
}
