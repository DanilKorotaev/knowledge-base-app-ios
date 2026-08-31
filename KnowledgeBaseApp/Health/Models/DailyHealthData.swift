import Foundation

/// Daily aggregate export shape (see project documentation for full JSON schema).
struct DailyHealthData: Codable, Equatable {
    var date: String
    var steps: Int
    var distanceKm: Double
    var activeCalories: Double
    var basalCalories: Double
    var totalCalories: Double
    var exerciseMinutes: Double
    var standHours: Double
    var restingHeartRate: Double?
    var hrvAverage: Double?
    var oxygenSaturationAverage: Double?
    var heartRate: HeartRateStats?
    var sleep: SleepSummary?
    var syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case distanceKm = "distance_km"
        case activeCalories = "active_calories"
        case basalCalories = "basal_calories"
        case totalCalories = "total_calories"
        case exerciseMinutes = "exercise_minutes"
        case standHours = "stand_hours"
        case restingHeartRate = "resting_heart_rate"
        case hrvAverage = "hrv_avg"
        case oxygenSaturationAverage = "spo2_avg"
        case heartRate = "heart_rate"
        case sleep
        case syncedAt = "synced_at"
    }
}

struct HeartRateStats: Codable, Equatable {
    var min: Double
    var max: Double
    var average: Double

    enum CodingKeys: String, CodingKey {
        case min
        case max
        case average = "avg"
    }
}

struct SleepSummary: Codable, Equatable {
    var totalMinutes: Double
    var deepMinutes: Double?
    var remMinutes: Double?
    var lightMinutes: Double?
    var awakeMinutes: Double?

    enum CodingKeys: String, CodingKey {
        case totalMinutes = "total_minutes"
        case deepMinutes = "deep_minutes"
        case remMinutes = "rem_minutes"
        case lightMinutes = "light_minutes"
        case awakeMinutes = "awake_minutes"
    }
}
