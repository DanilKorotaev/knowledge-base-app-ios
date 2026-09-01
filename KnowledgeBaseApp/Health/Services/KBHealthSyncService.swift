import Foundation

enum KBHealthSyncServiceError: Error, Equatable {
    case healthDataUnavailable
    case apiUnavailable
    case invalidDateRange
}

/// Orchestrates HealthKit export and upload via KB App API (no client-side WebDAV).
final class KBHealthSyncService {
    typealias ProgressHandler = (_ stage: String, _ uploadedFileCount: Int) -> Void

    private let healthKit: HealthKitServiceProtocol
    private let apiClient: HealthAPIClientProtocol
    private let clock: () -> Date
    private let jsonEncoder: () -> JSONEncoder
    private let calendar: Calendar
    private let uploadBatchSize: Int

    private static let syncStatePath = "sync_state.json"
    private static let workoutBatchLimit = 50

    static let defaultDailyBackfillMaxAgeDays = 1095

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
        calendar: Calendar = .current,
        uploadBatchSize: Int = 10
    ) {
        self.healthKit = healthKit
        self.apiClient = apiClient
        self.clock = clock
        self.jsonEncoder = jsonEncoder
        self.calendar = calendar
        self.uploadBatchSize = uploadBatchSize
    }

    /// Incremental workouts + today's daily summary. Does not export historical daily data.
    func syncRecent() async throws {
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
        var anchorData = remoteState?.workoutQueryAnchor.flatMap { Data(base64Encoded: $0) }
        var workoutAnchorBase64 = remoteState?.workoutQueryAnchor

        while true {
            let (batch, newAnchorData) = try await healthKit.fetchWorkoutsIncremental(
                anchor: anchorData,
                limit: Self.workoutBatchLimit
            )
            if let newAnchorData {
                workoutAnchorBase64 = newAnchorData.base64EncodedString()
            }
            if batch.isEmpty { break }
            for input in batch {
                let workout = healthKit.makeWorkoutData(from: input)
                let fileData = try encoder.encode(workout)
                pendingUploads.append((fileData, "workouts/\(input.date)_\(input.sourceIdentifier).json"))
                try await flushIfNeeded()
            }
            anchorData = newAnchorData
        }

        onProgress?("daily", uploadedCount)
        let dailyInput = try await healthKit.dailyAggregationInput(for: now)
        let daily = healthKit.makeDailyHealthData(from: dailyInput)
        pendingUploads.append((try encoder.encode(daily), "daily/\(dailyInput.date).json"))

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: dailyInput.date,
            workoutQueryAnchor: workoutAnchorBase64,
            dailyBackfillOldestCompleted: remoteState?.dailyBackfillOldestCompleted,
            notes: remoteState?.notes
        )
        pendingUploads.append((try encoder.encode(state), Self.syncStatePath))

        try await flushIfNeeded(force: true)
        SyncRunStore.recordSuccess(at: clock())
        onProgress?("done", uploadedCount)
    }

    /// Upload daily JSON files for each calendar day in the inclusive range.
    func syncDailyHistory(from startDate: Date, to endDate: Date) async throws {
        guard healthKit.isHealthDataAvailable else {
            throw KBHealthSyncServiceError.healthDataUnavailable
        }

        let range = normalizedDayRange(from: startDate, to: endDate)
        guard range.start <= range.end else {
            throw KBHealthSyncServiceError.invalidDateRange
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

        var mergedOldest = remoteState?.dailyBackfillOldestCompleted
        var latestDaily = remoteState?.lastDailyExportDate

        onProgress?("history", uploadedCount)
        var cursor = range.end
        while cursor >= range.start {
            let input = try await healthKit.dailyAggregationInput(for: cursor)
            let daily = healthKit.makeDailyHealthData(from: input)
            pendingUploads.append((try encoder.encode(daily), "daily/\(input.date).json"))
            mergedOldest = [mergedOldest, input.date].compactMap { $0 }.min()
            if latestDaily == nil || input.date > (latestDaily ?? "") {
                latestDaily = input.date
            }
            try await flushIfNeeded()
            onProgress?("history", uploadedCount + pendingUploads.count)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: latestDaily,
            workoutQueryAnchor: remoteState?.workoutQueryAnchor,
            dailyBackfillOldestCompleted: mergedOldest,
            notes: remoteState?.notes
        )
        pendingUploads.append((try encoder.encode(state), Self.syncStatePath))
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

    private func normalizedDayRange(from start: Date, to end: Date) -> (start: Date, end: Date) {
        let todayStart = calendar.startOfDay(for: clock())
        let rawStart = calendar.startOfDay(for: min(start, end))
        let rawEnd = calendar.startOfDay(for: max(start, end))
        let cappedEnd = min(rawEnd, todayStart)
        return (rawStart, cappedEnd)
    }
}
