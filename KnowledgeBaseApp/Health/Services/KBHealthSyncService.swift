import Foundation

enum KBHealthSyncServiceError: Error, Equatable {
    case healthDataUnavailable
    case apiUnavailable
    case invalidDateRange
}

/// Orchestrates HealthKit export and upload via KB App API (no client-side WebDAV).
final class KBHealthSyncService {
    typealias ProgressHandler = (_ stage: String, _ uploadedCount: Int, _ totalCount: Int?) -> Void

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

        onProgress?("workouts", 0, nil)
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
            }
            onProgress?("workouts", pendingUploads.count, nil)
            anchorData = newAnchorData
        }

        onProgress?("daily", pendingUploads.count, nil)
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

        try await uploadAll(pendingUploads)
        SyncRunStore.recordSuccess(at: clock())
        onProgress?("done", pendingUploads.count, pendingUploads.count)
    }

    /// Upload daily JSON files for each calendar day in the inclusive range.
    /// Exports and uploads in batches so multi-year backfills do not retain every day in memory.
    func syncDailyHistory(from startDate: Date, to endDate: Date) async throws {
        guard healthKit.isHealthDataAvailable else {
            throw KBHealthSyncServiceError.healthDataUnavailable
        }

        let range = normalizedDayRange(from: startDate, to: endDate)
        guard range.start <= range.end else {
            throw KBHealthSyncServiceError.invalidDateRange
        }

        let totalDays = inclusiveDayCount(from: range.start, to: range.end)
        let now = clock()
        let encoder = jsonEncoder()
        let remoteState = try await apiClient.fetchSyncState()

        var pendingBatch: [(Data, String)] = []
        var mergedOldest = remoteState?.dailyBackfillOldestCompleted
        var latestDaily = remoteState?.lastDailyExportDate
        var processedDays = 0
        var uploadedDailyFiles = 0
        let uploadTotal = totalDays + 1 // +1 for sync_state.json

        onProgress?("history", 0, totalDays)
        var cursor = range.end
        if let oldestKey = remoteState?.dailyBackfillOldestCompleted,
           let oldestDay = CalendarDayFormatter.startOfDay(fromYyyyMMdd: oldestKey, calendar: calendar),
           oldestDay >= range.start,
           let resumeCursor = calendar.date(byAdding: .day, value: -1, to: oldestDay) {
            cursor = min(cursor, resumeCursor)
        }
        while cursor >= range.start {
            let input = try await healthKit.dailyAggregationInput(for: cursor)
            let daily = healthKit.makeDailyHealthData(from: input)
            pendingBatch.append((try encoder.encode(daily), "daily/\(input.date).json"))
            mergedOldest = [mergedOldest, input.date].compactMap { $0 }.min()
            if latestDaily == nil || input.date > (latestDaily ?? "") {
                latestDaily = input.date
            }
            processedDays += 1
            onProgress?("history", processedDays, totalDays)
            try await flushDailyBatchIfNeeded(
                &pendingBatch,
                uploadedDailyFiles: &uploadedDailyFiles,
                uploadTotal: uploadTotal,
                encoder: encoder,
                remoteState: remoteState,
                mergedOldest: mergedOldest,
                latestDaily: latestDaily
            )
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        try await flushDailyBatchIfNeeded(
            &pendingBatch,
            uploadedDailyFiles: &uploadedDailyFiles,
            uploadTotal: uploadTotal,
            encoder: encoder,
            remoteState: remoteState,
            mergedOldest: mergedOldest,
            latestDaily: latestDaily,
            force: true
        )

        let state = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: now),
            lastDailyExportDate: latestDaily,
            workoutQueryAnchor: remoteState?.workoutQueryAnchor,
            dailyBackfillOldestCompleted: mergedOldest,
            notes: remoteState?.notes
        )
        let stateData = try encoder.encode(state)
        onProgress?("uploading", uploadedDailyFiles + 1, uploadTotal)
        _ = try await apiClient.uploadSyncFiles([
            HealthSyncFileUpload(path: Self.syncStatePath, data: stateData),
        ])

        SyncRunStore.recordSuccess(at: clock())
        onProgress?("done", uploadTotal, uploadTotal)
    }

    func loadTodayPreview() async throws -> DailyHealthData {
        guard healthKit.isHealthDataAvailable else {
            throw KBHealthSyncServiceError.healthDataUnavailable
        }
        let input = try await healthKit.dailyAggregationInput(for: clock())
        return healthKit.makeDailyHealthData(from: input)
    }

    private func uploadAll(_ pendingUploads: [(Data, String)]) async throws {
        let total = pendingUploads.count
        guard total > 0 else { return }
        var uploaded = 0
        var index = pendingUploads.startIndex
        while index < pendingUploads.endIndex {
            let end = pendingUploads.index(index, offsetBy: uploadBatchSize, limitedBy: pendingUploads.endIndex) ?? pendingUploads.endIndex
            let batch = Array(pendingUploads[index ..< end])
            let files = batch.map { HealthSyncFileUpload(path: $0.1, data: $0.0) }
            uploaded += batch.count
            onProgress?("uploading", uploaded, total)
            _ = try await apiClient.uploadSyncFiles(files)
            index = end
        }
    }

    private func normalizedDayRange(from start: Date, to end: Date) -> (start: Date, end: Date) {
        let todayStart = calendar.startOfDay(for: clock())
        let rawStart = calendar.startOfDay(for: min(start, end))
        let rawEnd = calendar.startOfDay(for: max(start, end))
        let cappedEnd = min(rawEnd, todayStart)
        return (rawStart, cappedEnd)
    }

    private func inclusiveDayCount(from start: Date, to end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dayDelta = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(0, dayDelta) + 1
    }

    private func flushDailyBatchIfNeeded(
        _ pendingBatch: inout [(Data, String)],
        uploadedDailyFiles: inout Int,
        uploadTotal: Int,
        encoder: JSONEncoder,
        remoteState: SyncState?,
        mergedOldest: String?,
        latestDaily: String?,
        force: Bool = false
    ) async throws {
        guard force || pendingBatch.count >= uploadBatchSize else { return }
        guard !pendingBatch.isEmpty else { return }
        uploadedDailyFiles += pendingBatch.count
        onProgress?("uploading", uploadedDailyFiles, uploadTotal)
        let files = pendingBatch.map { HealthSyncFileUpload(path: $0.1, data: $0.0) }
        _ = try await apiClient.uploadSyncFiles(files)
        pendingBatch.removeAll(keepingCapacity: true)

        let checkpoint = SyncState(
            lastSyncedAt: CalendarDayFormatter.iso8601UTCSeconds(from: clock()),
            lastDailyExportDate: latestDaily,
            workoutQueryAnchor: remoteState?.workoutQueryAnchor,
            dailyBackfillOldestCompleted: mergedOldest,
            notes: remoteState?.notes
        )
        let stateData = try encoder.encode(checkpoint)
        _ = try await apiClient.uploadSyncFiles([
            HealthSyncFileUpload(path: Self.syncStatePath, data: stateData),
        ])
    }
}
