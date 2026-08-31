import Foundation

/// Workout export shape (see project documentation for full JSON schema).
struct WorkoutData: Codable, Equatable {
    /// Stable HealthKit workout UUID (for filenames and server-side linking).
    var sourceIdentifier: String?
    var date: String
    var workoutType: String
    var workoutTypeDisplay: String
    var isGym: Bool
    var durationMinutes: Double
    var distanceKm: Double?
    var activeCalories: Double?
    var totalCalories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateZones: HeartRateZones?
    var linkedNote: String?
    var syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case sourceIdentifier = "source_id"
        case date
        case workoutType = "workout_type"
        case workoutTypeDisplay = "workout_type_display"
        case isGym = "is_gym"
        case durationMinutes = "duration_minutes"
        case distanceKm = "distance_km"
        case activeCalories = "active_calories"
        case totalCalories = "total_calories"
        case averageHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case heartRateZones = "heart_rate_zones"
        case linkedNote = "linked_note"
        case syncedAt = "synced_at"
    }
}

struct HeartRateZones: Codable, Equatable {
    var zone1Below60: Double
    var zone2From60To70: Double
    var zone3From70To80: Double
    var zone4From80To90: Double
    var zone5Above90: Double

    enum CodingKeys: String, CodingKey {
        case zone1Below60 = "zone1_below_60"
        case zone2From60To70 = "zone2_60_70"
        case zone3From70To80 = "zone3_70_80"
        case zone4From80To90 = "zone4_80_90"
        case zone5Above90 = "zone5_above_90"
    }
}
