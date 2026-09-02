import Foundation
import HealthKit
import Testing
@testable import KnowledgeBaseApp

@Suite("KBHealthSyncService")
struct KBHealthSyncServiceTests {
    @Test("syncRecent uploads daily and sync_state when no workouts")
    func syncRecentUploadsDailyAndState() async throws {
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
        let healthKit = MockHealthKitService()
        healthKit.isHealthDataAvailable = true
        healthKit.dailyInput = DailyAggregationInput(
            date: "2026-03-01",
            steps: 5000,
            distanceKm: 3.2,
            activeCalories: 400,
            basalCalories: 1200,
            exerciseMinutes: 30,
            standHours: 8,
            restingHeartRate: 58,
            hrvValues: [],
            oxygenSaturationValues: [],
            heartRateValues: [],
            heartRateSummary: nil,
            sleep: nil,
            activityRings: nil,
            syncedAt: nil
        )

        let api = StubHealthAPIClient()
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            uploadBatchSize: 5
        )

        try await service.syncRecent()

        #expect(api.uploadedFiles.contains { $0.path == "daily/2026-03-01.json" })
        #expect(api.uploadedFiles.contains { $0.path == "sync_state.json" })
        #expect(!api.uploadedFiles.contains { $0.path.hasPrefix("daily/2026-02") })
    }

    @Test("syncRecent throws when HealthKit is unavailable")
    func syncRecentThrowsWhenUnavailable() async {
        let healthKit = MockHealthKitService()
        healthKit.isHealthDataAvailable = false
        let service = KBHealthSyncService(healthKit: healthKit, apiClient: StubHealthAPIClient())
        await #expect(throws: KBHealthSyncServiceError.healthDataUnavailable) {
            try await service.syncRecent()
        }
    }

    @Test("syncRecent uploads workout JSON files")
    func syncRecentUploadsWorkouts() async throws {
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
        let healthKit = MockHealthKitService()
        healthKit.workoutBatches = [
            (
                [
                    WorkoutAggregationInput(
                        sourceIdentifier: "ABC",
                        date: "2026-03-01",
                        startAt: fixedDate,
                        endAt: fixedDate.addingTimeInterval(1800),
                        workoutType: "running",
                        durationMinutes: 30,
                        distanceKm: 5,
                        elevationGainM: nil,
                        averagePaceMinPerKm: 6,
                        activeCalories: 300,
                        totalCalories: 350,
                        heartRateSamples: [],
                        route: nil,
                        linkedNote: nil,
                        syncedAt: nil
                    ),
                ],
                Data([0x01])
            ),
            ([], Data([0x01])),
        ]

        let api = StubHealthAPIClient()
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            uploadBatchSize: 10
        )

        try await service.syncRecent()

        #expect(api.uploadedFiles.contains { $0.path == "workouts/2026-03-01_ABC.json" })
    }

    @Test("syncDailyHistory uploads each day in range")
    func syncDailyHistoryUploadsRange() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!
        let healthKit = MockHealthKitService()
        healthKit.dailyInput = DailyAggregationInput(
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

        let start = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 3)))
        let end = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        let api = StubHealthAPIClient()
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            calendar: utc,
            uploadBatchSize: 10
        )

        try await service.syncDailyHistory(from: start, to: end)

        let dailyPaths = api.uploadedFiles.filter { $0.path.hasPrefix("daily/") }.map(\.path)
        #expect(dailyPaths.contains("daily/2026-03-03.json"))
        #expect(dailyPaths.contains("daily/2026-03-04.json"))
        #expect(api.uploadedFiles.contains { $0.path == "sync_state.json" })
        #expect(api.uploadedFiles.filter { $0.path == "sync_state.json" }.count >= 1)
    }

    @Test("syncDailyHistory resumes after checkpoint")
    func syncDailyHistoryResumesAfterCheckpoint() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!
        let healthKit = MockHealthKitService()
        let api = StubHealthAPIClient()
        api.syncState = SyncState(
            lastSyncedAt: "2026-03-01T12:00:00Z",
            lastDailyExportDate: "2026-03-04",
            workoutQueryAnchor: nil,
            dailyBackfillOldestCompleted: "2026-03-04",
            notes: nil
        )
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            calendar: utc,
            uploadBatchSize: 10
        )

        let start = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 3)))
        let end = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        try await service.syncDailyHistory(from: start, to: end)

        let dailyPaths = api.uploadedFiles.filter { $0.path.hasPrefix("daily/") }.map(\.path)
        #expect(dailyPaths == ["daily/2026-03-03.json"])
    }

    @Test("syncDailyHistory streams uploads in batches")
    func syncDailyHistoryStreamsBatches() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!
        let healthKit = MockHealthKitService()
        let api = StubHealthAPIClient()
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            calendar: utc,
            uploadBatchSize: 1
        )

        let start = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 3)))
        let end = try #require(utc.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        try await service.syncDailyHistory(from: start, to: end)

        let dailyPaths = api.uploadedFiles.filter { $0.path.hasPrefix("daily/") }.map(\.path)
        #expect(dailyPaths.count == 2)
        #expect(api.uploadedFiles.contains { $0.path == "sync_state.json" })
    }

    @Test("loadTodayPreview returns daily data")
    func loadTodayPreview() async throws {
        let healthKit = MockHealthKitService()
        healthKit.dailyInput.steps = 1234
        let service = KBHealthSyncService(healthKit: healthKit, apiClient: StubHealthAPIClient())
        let daily = try await service.loadTodayPreview()
        #expect(daily.steps == 1234)
    }
}

private final class MockHealthKitService: HealthKitServiceProtocol {
    var isHealthDataAvailable = true
    var requiredReadTypes: Set<HKObjectType> = []
    var dailyInput = DailyAggregationInput(
        date: "2026-03-01",
        steps: 0,
        distanceKm: 0,
        activeCalories: 0,
        basalCalories: 0,
        exerciseMinutes: 0,
        standHours: 0,
        restingHeartRate: nil,
        hrvValues: [],
        oxygenSaturationValues: [],
        heartRateValues: [],
        heartRateSummary: nil,
        sleep: nil,
        activityRings: nil,
        syncedAt: nil
    )
    var workoutBatches: [(workouts: [WorkoutAggregationInput], newAnchor: Data?)] = []

    func requestReadAuthorization() async throws {}

    func needsReadAuthorization() async -> Bool { false }

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        var copy = dailyInput
        copy.date = CalendarDayFormatter.yyyyMMdd(for: date)
        return copy
    }

    func makeDailyHealthData(from input: DailyAggregationInput) -> DailyHealthData {
        HealthKitService().makeDailyHealthData(from: input)
    }

    func makeWorkoutData(from input: WorkoutAggregationInput) -> WorkoutData {
        HealthKitService().makeWorkoutData(from: input)
    }

    func fetchWorkoutsIncremental(anchor: Data?, limit: Int) async throws -> (workouts: [WorkoutAggregationInput], newAnchor: Data?) {
        if workoutBatches.isEmpty {
            return ([], anchor)
        }
        let next = workoutBatches.removeFirst()
        return (next.workouts, next.newAnchor)
    }
}
