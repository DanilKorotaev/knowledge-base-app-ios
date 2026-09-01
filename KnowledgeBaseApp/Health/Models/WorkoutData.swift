import Foundation

/// Workout export shape — stable `workout_type` slug from HealthKit; display names belong in KB scripts.
struct WorkoutData: Codable, Equatable {
    var sourceIdentifier: String?
    var date: String
    var startAt: String?
    var endAt: String?
    var workoutType: String
    var durationMinutes: Double
    var distanceKm: Double?
    var elevationGainM: Double?
    /// Minutes per kilometer when distance is available.
    var averagePaceMinPerKm: Double?
    var activeCalories: Double?
    var totalCalories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateZones: WorkoutHeartRateZonesSummary?
    var heartRateSamples: [HeartRateSamplePoint]?
    var route: WorkoutRouteExport?
    var linkedNote: String?
    var syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case sourceIdentifier = "source_id"
        case date
        case startAt = "start_at"
        case endAt = "end_at"
        case workoutType = "workout_type"
        case durationMinutes = "duration_minutes"
        case distanceKm = "distance_km"
        case elevationGainM = "elevation_gain_m"
        case averagePaceMinPerKm = "average_pace_min_per_km"
        case activeCalories = "active_calories"
        case totalCalories = "total_calories"
        case averageHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case heartRateZones = "heart_rate_zones"
        case heartRateSamples = "heart_rate_samples"
        case route
        case linkedNote = "linked_note"
        case syncedAt = "synced_at"
    }
}

struct HeartRateSamplePoint: Codable, Equatable {
    var timestamp: String
    var bpm: Double
}

struct WorkoutHeartRateZonesSummary: Codable, Equatable {
    /// Max heart rate (bpm) used to derive zone thresholds — typically 220 − age or observed max.
    var maxHeartRateBpm: Double
    var zones: [HeartRateZoneEntry]
}

struct HeartRateZoneEntry: Codable, Equatable {
    var zone: Int
    var bpmMin: Double?
    var bpmMax: Double?
    var minutes: Double

    enum CodingKeys: String, CodingKey {
        case zone
        case bpmMin = "bpm_min"
        case bpmMax = "bpm_max"
        case minutes
    }
}

struct WorkoutRouteExport: Codable, Equatable {
    var points: [RoutePoint]
}

struct RoutePoint: Codable, Equatable {
    var lat: Double
    var lon: Double
    var timestamp: String?
    var altitudeM: Double?

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case timestamp
        case altitudeM = "altitude_m"
    }
}
