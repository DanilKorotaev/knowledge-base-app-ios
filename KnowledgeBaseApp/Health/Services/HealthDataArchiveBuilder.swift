import Foundation
import ZIPFoundation

enum HealthDataArchiveBuilderError: Error, Equatable {
    case healthDataUnavailable
    case emptyArchive
}

/// Builds a local ZIP mirroring the server `HealthData/` layout from HealthKit exports.
struct HealthDataArchiveBuilder {
    private let healthKit: HealthKitServiceProtocol
    private let calendar: Calendar
    private let jsonEncoder: () -> JSONEncoder

    init(
        healthKit: HealthKitServiceProtocol = HealthKitService(),
        calendar: Calendar = .current,
        jsonEncoder: @escaping () -> JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }
    ) {
        self.healthKit = healthKit
        self.calendar = calendar
        self.jsonEncoder = jsonEncoder
    }

    func buildArchive(
        dailyFrom: Date,
        dailyTo: Date,
        includeWorkouts: Bool,
        onProgress: ((String, Int) -> Void)? = nil
    ) async throws -> URL {
        guard healthKit.isHealthDataAvailable else {
            throw HealthDataArchiveBuilderError.healthDataUnavailable
        }

        let encoder = jsonEncoder()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthData-export-\(UUID().uuidString)", isDirectory: true)
        let healthRoot = root.appendingPathComponent("HealthData", isDirectory: true)
        let dailyDir = healthRoot.appendingPathComponent("daily", isDirectory: true)
        let workoutsDir = healthRoot.appendingPathComponent("workouts", isDirectory: true)

        try FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)
        if includeWorkouts {
            try FileManager.default.createDirectory(at: workoutsDir, withIntermediateDirectories: true)
        }

        var fileCount = 0
        let range = normalizedDayRange(from: dailyFrom, to: dailyTo)
        onProgress?("daily", fileCount)
        var cursor = range.end
        while cursor >= range.start {
            let input = try await healthKit.dailyAggregationInput(for: cursor)
            let daily = healthKit.makeDailyHealthData(from: input)
            let data = try encoder.encode(daily)
            let fileURL = dailyDir.appendingPathComponent("\(input.date).json")
            try data.write(to: fileURL)
            fileCount += 1
            onProgress?("daily", fileCount)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        if includeWorkouts {
            onProgress?("workouts", fileCount)
            var anchor: Data?
            while true {
                let (batch, newAnchor) = try await healthKit.fetchWorkoutsIncremental(anchor: anchor, limit: 50)
                if let newAnchor { anchor = newAnchor }
                if batch.isEmpty { break }
                for input in batch {
                    let workout = healthKit.makeWorkoutData(from: input)
                    let data = try encoder.encode(workout)
                    let fileURL = workoutsDir.appendingPathComponent("\(input.date)_\(input.sourceIdentifier).json")
                    try data.write(to: fileURL)
                    fileCount += 1
                    onProgress?("workouts", fileCount)
                }
            }
        }

        guard fileCount > 0 else {
            try? FileManager.default.removeItem(at: root)
            throw HealthDataArchiveBuilderError.emptyArchive
        }

        let manifest: [String: Any] = [
            "exported_at": CalendarDayFormatter.iso8601UTCSeconds(from: Date()),
            "daily_from": CalendarDayFormatter.yyyyMMdd(for: range.start),
            "daily_to": CalendarDayFormatter.yyyyMMdd(for: range.end),
            "includes_workouts": includeWorkouts,
            "file_count": fileCount,
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: healthRoot.appendingPathComponent("export_manifest.json"))

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthData-\(CalendarDayFormatter.yyyyMMdd(for: Date())).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try FileManager.default.zipItem(at: root, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: root)
        onProgress?("done", fileCount)
        return zipURL
    }

    private func normalizedDayRange(from start: Date, to end: Date) -> (start: Date, end: Date) {
        let todayStart = calendar.startOfDay(for: Date())
        let rawStart = calendar.startOfDay(for: min(start, end))
        let rawEnd = calendar.startOfDay(for: max(start, end))
        let cappedEnd = min(rawEnd, todayStart)
        return (rawStart, cappedEnd)
    }
}
