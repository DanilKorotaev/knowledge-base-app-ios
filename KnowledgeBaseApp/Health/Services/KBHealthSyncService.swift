import Foundation

enum KBHealthSyncServiceError: Error, Equatable {
    case healthDataUnavailable
    case apiUnavailable
}

/// Orchestrates HealthKit export and upload via KB App API (no client-side WebDAV).
final class KBHealthSyncService {
    typealias ProgressHandler = (_ stage: String, _ uploadedFileCount: Int) -> Void

    private let healthKit: HealthKitServiceProtocol
    private let apiClient: HealthAPIClientProtocol
    private let clock: () -> Date
    private let jsonEncoder: () -> JSONEncoder
    private let jsonDecoder: () -> JSONDecoder
    private let calendar: Calendar
    private let dailyBackfillMaxAgeDays: Int
    private let dailyBackfillBatchSize: Int
    private let uploadBatchSize: Int

    private static let syncStatePath = "sync_state.json"
    private static let workoutBatchLimit = 50

    var onProgress: ProgressHandler?

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        apiClient: HealthAPIClientProtocol,
        clock: @escaping () -> Date = Date.init,
        jsonEncoder: @escaping () -> JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        },
        jsonDecoder: @escaping () -> JSONDecoder = { JSONDecoder() },
        calendar: Calendar = .current,
        dailyBackfillMaxAgeDays: Int = 730,
        dailyBackfillBatchSize: Int = 7,
        uploadBatchSize: Int = 10
    ) {
        self.healthKit = healthKit
        self.apiClient = apiClient
        self.clock = clock
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.calendar = calendar
        self.dailyBackfillMaxAgeDays = dailyBackfillMaxAgeDays
        self.dailyBackfillBatchSize = dailyBackfillBatchSize
        self.uploadBatchSize = uploadBatchSize
    }

    func syncNow() async throws {
        guard healthKit.isHealthDataAvailable else {
            throw KBHealthSyncServiceError.healthDataUnavailable
        }

        let now = clock()
        let encoder = jsonEncoder()
        let remoteState = try await apiClient.fetchSyncState()

        var pendingUploads: [(Data, String)] = []
        var uploadedCount = 0

        func flushIfNeeded(force: Bool = false) async throws {
            guard force || pendingUploads.count >= uploadBatchSize else { return }
            guard !pendingUploads.isEmpty else { return }
            let batch = pendingUploads
            pendingUploads = []
            try await upload(batch: batch, uploadedSoFar: uploadedCount)
            uploadedCount += batch.count
        }

        onProgress?("workouts", uploadedCount)

        var anchorData: Data? = remoteState?.workoutQueryAnchor.flatMap { Data(base64Encoded: $0) }
        var workoutAnchorBase64: String? = remoteState?.workoutQueryAnchor

        while true {
            let (batch, newAnchorData) = try await healthKit.fetchWorkoutsIncremental(
                anchor: anchorData,
                limit: Self.workoutBatchLimit
            )
            if let newAnchorData {
                workoutAnchorBase64 = newAnchorData.base64EncodedString()
            }
            if batch.isEmpty {
                break
            }
            for input in batch {
                let workout = healthKit.makeWorkoutData(from: input)
                let fileData = try encoder.encode(workout)
                let path = "workouts/\(input.date)_\(input.sourceIdentifier).json"
                pendingUploads.append((fileData, path))
                try await flushIfNeeded()
            }
            anchorData = newAnchorData
        }

        onProgress?("daily", uploadedCount)

        let dailyInput = try await healthKit.dailyAggregationInput(for: now)
        let daily = healthKit.makeDailyHealthData(from: dailyInput)
        let dailyData = try encoder.encode(daily)
        let dayKey = dailyInput.date
        pendingUploads.append((dailyData, "daily/\(dayKey).json"))

        var dailyBackfillOldest = remoteState?.dailyBackfillOldestCompleted
        if dailyBackfillBatchSize > 0 {
            onProgress?("backfill", uploadedCount)
            let result = try await dailyBackfillEntries(
                now: now,
                encoder: encoder,
                remoteState: remoteState,
                startingMergedOldest: dailyBackfillOldest
            )
            for payload in result.payloads {
                pendingUploads.append((payload.data, payload.path))
                try await flushIfNeeded()
            }
            dailyBackfillOldest = result.mergedOldestCompleted
        }

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: dayKey,
            workoutQueryAnchor: workoutAnchorBase64,
            dailyBackfillOldestCompleted: dailyBackfillOldest,
            notes: remoteState?.notes
        )
        let stateData = try encoder.encode(state)
        pendingUploads.append((stateData, Self.syncStatePath))

        try await flushIfNeeded(force: true)
        SyncRunStore.recordSuccess(at: clock())
        onProgress?("done", uploadedCount)
    }

    func loadTodayPreview() async throws -> DailyHealthData {
        guard healthKit.isHealthDataAvailable else {
            throw KBHealthSyncServiceError.healthDataUnavailable
        }
        let input = try await healthKit.dailyAggregationInput(for: clock())
        return healthKit.makeDailyHealthData(from: input)
    }

    private func upload(batch: [(Data, String)], uploadedSoFar: Int) async throws {
        let files = batch.map { HealthSyncFileUpload(path: $0.1, data: $0.0) }
        onProgress?("uploading", uploadedSoFar + files.count)
        _ = try await apiClient.uploadSyncFiles(files)
    }

    private struct DailyBackfillPayload {
        let data: Data
        let path: String
    }

    private func dailyBackfillEntries(
        now: Date,
        encoder: JSONEncoder,
        remoteState: SyncState?,
        startingMergedOldest: String?
    ) async throws -> (paths: [String], payloads: [DailyBackfillPayload], mergedOldestCompleted: String?) {
        let todayStart = calendar.startOfDay(for: now)
        guard let minDate = calendar.date(byAdding: .day, value: -dailyBackfillMaxAgeDays, to: todayStart),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return ([], [], startingMergedOldest)
        }

        let startCursor: Date
        if let oldestStr = remoteState?.dailyBackfillOldestCompleted,
           let oldestDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: oldestStr, calendar: calendar) {
            let oldestStart = calendar.startOfDay(for: oldestDay)
            startCursor = calendar.date(byAdding: .day, value: -1, to: oldestStart) ?? oldestStart
        } else {
            startCursor = calendar.startOfDay(for: yesterday)
        }

        var cursor = startCursor
        var paths: [String] = []
        var payloads: [DailyBackfillPayload] = []
        var mergedOldest = startingMergedOldest
        var uploadCount = 0

        while uploadCount < dailyBackfillBatchSize {
            if cursor < minDate {
                break
            }
            let input = try await healthKit.dailyAggregationInput(for: cursor)
            let daily = healthKit.makeDailyHealthData(from: input)
            let data = try encoder.encode(daily)
            let path = "daily/\(input.date).json"
            paths.append(path)
            payloads.append(DailyBackfillPayload(data: data, path: path))
            mergedOldest = [mergedOldest, input.date].compactMap { $0 }.min()
            uploadCount += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = prev
        }

        return (paths, payloads, mergedOldest)
    }
}
