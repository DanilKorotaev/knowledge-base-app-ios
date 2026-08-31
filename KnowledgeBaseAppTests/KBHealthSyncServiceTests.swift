import Foundation
import HealthKit
import Testing
@testable import KnowledgeBaseApp

@Suite("KBHealthSyncService")
struct KBHealthSyncServiceTests {
    @Test("uploads daily and sync_state when no workouts")
    func syncNowUploadsDailyAndState() async throws {
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
            syncedAt: nil
        )

        let api = StubHealthAPIClient()
        let service = KBHealthSyncService(
            healthKit: healthKit,
            apiClient: api,
            clock: { fixedDate },
            dailyBackfillBatchSize: 0,
            uploadBatchSize: 5
        )

        try await service.syncNow()

        #expect(api.uploadedFiles.contains { $0.path == "daily/2026-03-01.json" })
        #expect(api.uploadedFiles.contains { $0.path == "sync_state.json" })
    }

    @Test("throws when HealthKit is unavailable")
    func syncNowThrowsWhenUnavailable() async {
        let healthKit = MockHealthKitService()
        healthKit.isHealthDataAvailable = false
        let service = KBHealthSyncService(healthKit: healthKit, apiClient: StubHealthAPIClient())
        await #expect(throws: KBHealthSyncServiceError.healthDataUnavailable) {
            try await service.syncNow()
        }
    }

    @Test("uploads workout JSON files")
    func syncNowUploadsWorkouts() async throws {
        let fixedDate = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
        let healthKit = MockHealthKitService()
        healthKit.workoutBatches = [
            (
                [
                    WorkoutAggregationInput(
                        sourceIdentifier: "ABC",
                        date: "2026-03-01",
                        workoutType: "running",
                        workoutTypeDisplay: "Running",
                        isGym: false,
                        durationMinutes: 30,
                        distanceKm: 5,
                        activeCalories: 300,
                        totalCalories: 350,
                        heartRateSamples: [],
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
            dailyBackfillBatchSize: 0,
            uploadBatchSize: 10
        )

        try await service.syncNow()

        #expect(api.uploadedFiles.contains { $0.path == "workouts/2026-03-01_ABC.json" })
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
        syncedAt: nil
    )
    var workoutBatches: [(workouts: [WorkoutAggregationInput], newAnchor: Data?)] = []

    func requestReadAuthorization() async throws {}

    func dailyAggregationInput(for date: Date) async throws -> DailyAggregationInput {
        dailyInput
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
