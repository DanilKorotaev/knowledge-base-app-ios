import Foundation
import HealthKit
import Testing
@testable import KnowledgeBaseApp

@Suite("Health utilities")
struct HealthUtilitiesTests {
    @Test("WorkoutTypeSlug maps common HealthKit activity types")
    func workoutTypeSlugMapsKnownActivities() {
        #expect(WorkoutTypeSlug.snakeCase(.walking) == "walking")
        #expect(WorkoutTypeSlug.snakeCase(.traditionalStrengthTraining) == "traditional_strength_training")
        #expect(WorkoutTypeSlug.snakeCase(.running) == "running")
        #expect(WorkoutTypeSlug.displayName(for: .walking) == "Walking")
    }

    @Test("CalendarDayFormatter formats UTC day key")
    func calendarDayFormatterUTC() {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = formatter.date(from: "2026-03-01T12:00:00Z")!
        #expect(CalendarDayFormatter.yyyyMMdd(for: date) == "2026-03-01")
    }

    @Test("CalendarDayFormatter parses yyyy-MM-dd start of day")
    func calendarDayFormatterStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = CalendarDayFormatter.startOfDay(fromYyyyMMdd: "2026-03-01", calendar: calendar)
        #expect(date != nil)
        #expect(CalendarDayFormatter.yyyyMMddLocalDay(containing: date!, calendar: calendar) == "2026-03-01")
    }

    @Test("SyncState round-trips JSON keys")
    func syncStateCodable() throws {
        let state = SyncState(
            lastSyncedAt: "2026-01-01T00:00:00Z",
            lastDailyExportDate: "2026-01-01",
            workoutQueryAnchor: "abc",
            dailyBackfillOldestCompleted: "2025-12-01",
            notes: "ok"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SyncState.self, from: data)
        #expect(decoded == state)
    }

    @Test("HealthBackgroundTaskIdentifier lists permitted IDs")
    func backgroundTaskIdentifiers() {
        #expect(HealthBackgroundTaskIdentifier.permitted.count == 2)
        #expect(HealthBackgroundTaskIdentifier.permitted.contains(HealthBackgroundTaskIdentifier.refresh))
    }

    @Test("SyncRunStore records last success")
    func syncRunStore() {
        let defaults = UserDefaults.standard
        let key = "kb.health.last_successful_sync_at"
        let previous = defaults.double(forKey: key)
        defer { defaults.set(previous, forKey: key) }

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        SyncRunStore.recordSuccess(at: date)
        #expect(SyncRunStore.lastSuccessfulSyncAt == date)
    }
}

@Suite("HealthSyncViewModel")
@MainActor
struct HealthSyncViewModelTests {
    @Test("refresh loads settings and preview when HealthKit available")
    func refreshLoadsPreview() async {
        let healthKit = ViewModelHealthKitMock()
        let api = StubHealthAPIClient()
        api.settings = HealthUserSettings(healthDataRelative: "HealthData/test")
        let viewModel = HealthSyncViewModel(healthKit: healthKit, apiClient: api)

        await viewModel.refresh()

        #expect(viewModel.healthDataRelative == "HealthData/test")
        #expect(viewModel.todayPreview?.steps == 100)
        #expect(viewModel.phase == .idle)
    }

    @Test("updateHealthFolder persists via API client")
    func updateHealthFolder() async {
        let api = StubHealthAPIClient()
        let viewModel = HealthSyncViewModel(healthKit: ViewModelHealthKitMock(), apiClient: api)

        await viewModel.updateHealthFolder("HealthData/new")

        #expect(viewModel.healthDataRelative == "HealthData/new")
    }
}

private final class ViewModelHealthKitMock: HealthKitServiceProtocol {
    var isHealthDataAvailable = true
    var requiredReadTypes: Set<HKObjectType> = []

    func requestReadAuthorization() async throws {}

    func needsReadAuthorization() async -> Bool { false }

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        DailyAggregationInput(
            date: "2026-03-01",
            steps: 100,
            distanceKm: 1,
            activeCalories: 10,
            basalCalories: 20,
            exerciseMinutes: 5,
            standHours: 1,
            restingHeartRate: nil,
            hrvValues: [],
            oxygenSaturationValues: [],
            heartRateValues: [],
            heartRateSummary: nil,
            sleep: nil,
            activityRings: nil,
            syncedAt: nil
        )
    }

    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData {
        HealthKitService(healthStore: HealthStoreMock()).makeDailyHealthData(from: input)
    }

    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData {
        HealthKitService(healthStore: HealthStoreMock()).makeWorkoutData(from: input)
    }

    func fetchWorkoutsIncremental(anchor: Data?, limit: Int) async throws -> (workouts: [WorkoutAggregationInput], newAnchor: Data?) {
        ([], anchor)
    }
}

private final class HealthStoreMock: HealthStoreProtocol, DailyHealthKitDataProviding {
    var isHealthDataAvailable = true

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {}

    func readAuthorizationRequestStatus(read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        .unnecessary
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

    func activitySummary(for dayStart: Date, calendar: Calendar) async throws -> HKActivitySummary? { nil }
}
