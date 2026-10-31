import Foundation
import HealthKit

enum WorkoutTypeSlug {
    /// Lookup by `HKWorkoutActivityType.rawValue` keeps cyclomatic complexity flat as Apple adds cases.
    private static let snakeCaseByRawValue: [UInt: String] = [
        HKWorkoutActivityType.americanFootball.rawValue: "american_football",
        HKWorkoutActivityType.archery.rawValue: "archery",
        HKWorkoutActivityType.australianFootball.rawValue: "australian_football",
        HKWorkoutActivityType.badminton.rawValue: "badminton",
        HKWorkoutActivityType.baseball.rawValue: "baseball",
        HKWorkoutActivityType.basketball.rawValue: "basketball",
        HKWorkoutActivityType.bowling.rawValue: "bowling",
        HKWorkoutActivityType.boxing.rawValue: "boxing",
        HKWorkoutActivityType.climbing.rawValue: "climbing",
        HKWorkoutActivityType.cricket.rawValue: "cricket",
        HKWorkoutActivityType.crossTraining.rawValue: "cross_training",
        HKWorkoutActivityType.curling.rawValue: "curling",
        HKWorkoutActivityType.cycling.rawValue: "cycling",
        HKWorkoutActivityType.dance.rawValue: "dance",
        HKWorkoutActivityType.danceInspiredTraining.rawValue: "dance_inspired_training",
        HKWorkoutActivityType.elliptical.rawValue: "elliptical",
        HKWorkoutActivityType.equestrianSports.rawValue: "equestrian_sports",
        HKWorkoutActivityType.fencing.rawValue: "fencing",
        HKWorkoutActivityType.fishing.rawValue: "fishing",
        HKWorkoutActivityType.functionalStrengthTraining.rawValue: "functional_strength_training",
        HKWorkoutActivityType.golf.rawValue: "golf",
        HKWorkoutActivityType.gymnastics.rawValue: "gymnastics",
        HKWorkoutActivityType.handball.rawValue: "handball",
        HKWorkoutActivityType.hiking.rawValue: "hiking",
        HKWorkoutActivityType.hockey.rawValue: "hockey",
        HKWorkoutActivityType.hunting.rawValue: "hunting",
        HKWorkoutActivityType.lacrosse.rawValue: "lacrosse",
        HKWorkoutActivityType.martialArts.rawValue: "martial_arts",
        HKWorkoutActivityType.mindAndBody.rawValue: "mind_and_body",
        HKWorkoutActivityType.paddleSports.rawValue: "paddle_sports",
        HKWorkoutActivityType.play.rawValue: "play",
        HKWorkoutActivityType.preparationAndRecovery.rawValue: "preparation_and_recovery",
        HKWorkoutActivityType.racquetball.rawValue: "racquetball",
        HKWorkoutActivityType.rowing.rawValue: "rowing",
        HKWorkoutActivityType.rugby.rawValue: "rugby",
        HKWorkoutActivityType.running.rawValue: "running",
        HKWorkoutActivityType.sailing.rawValue: "sailing",
        HKWorkoutActivityType.skatingSports.rawValue: "skating_sports",
        HKWorkoutActivityType.snowSports.rawValue: "snow_sports",
        HKWorkoutActivityType.soccer.rawValue: "soccer",
        HKWorkoutActivityType.softball.rawValue: "softball",
        HKWorkoutActivityType.squash.rawValue: "squash",
        HKWorkoutActivityType.stairClimbing.rawValue: "stair_climbing",
        HKWorkoutActivityType.surfingSports.rawValue: "surfing_sports",
        HKWorkoutActivityType.swimming.rawValue: "swimming",
        HKWorkoutActivityType.tableTennis.rawValue: "table_tennis",
        HKWorkoutActivityType.tennis.rawValue: "tennis",
        HKWorkoutActivityType.trackAndField.rawValue: "track_and_field",
        HKWorkoutActivityType.traditionalStrengthTraining.rawValue: "traditional_strength_training",
        HKWorkoutActivityType.volleyball.rawValue: "volleyball",
        HKWorkoutActivityType.walking.rawValue: "walking",
        HKWorkoutActivityType.waterFitness.rawValue: "water_fitness",
        HKWorkoutActivityType.waterPolo.rawValue: "water_polo",
        HKWorkoutActivityType.waterSports.rawValue: "water_sports",
        HKWorkoutActivityType.wrestling.rawValue: "wrestling",
        HKWorkoutActivityType.yoga.rawValue: "yoga",
        HKWorkoutActivityType.barre.rawValue: "barre",
        HKWorkoutActivityType.coreTraining.rawValue: "core_training",
        HKWorkoutActivityType.crossCountrySkiing.rawValue: "cross_country_skiing",
        HKWorkoutActivityType.downhillSkiing.rawValue: "downhill_skiing",
        HKWorkoutActivityType.flexibility.rawValue: "flexibility",
        HKWorkoutActivityType.highIntensityIntervalTraining.rawValue: "high_intensity_interval_training",
        HKWorkoutActivityType.jumpRope.rawValue: "jump_rope",
        HKWorkoutActivityType.kickboxing.rawValue: "kickboxing",
        HKWorkoutActivityType.pilates.rawValue: "pilates",
        HKWorkoutActivityType.snowboarding.rawValue: "snowboarding",
        HKWorkoutActivityType.stairs.rawValue: "stairs",
        HKWorkoutActivityType.stepTraining.rawValue: "step_training",
        HKWorkoutActivityType.wheelchairWalkPace.rawValue: "wheelchair_walk_pace",
        HKWorkoutActivityType.wheelchairRunPace.rawValue: "wheelchair_run_pace",
        HKWorkoutActivityType.taiChi.rawValue: "tai_chi",
        HKWorkoutActivityType.mixedCardio.rawValue: "mixed_cardio",
        HKWorkoutActivityType.handCycling.rawValue: "hand_cycling",
        HKWorkoutActivityType.discSports.rawValue: "disc_sports",
        HKWorkoutActivityType.fitnessGaming.rawValue: "fitness_gaming",
        HKWorkoutActivityType.pickleball.rawValue: "pickleball",
        HKWorkoutActivityType.cooldown.rawValue: "cooldown",
        HKWorkoutActivityType.swimBikeRun.rawValue: "swim_bike_run",
        HKWorkoutActivityType.transition.rawValue: "transition",
        HKWorkoutActivityType.underwaterDiving.rawValue: "underwater_diving",
        HKWorkoutActivityType.mixedMetabolicCardioTraining.rawValue: "mixed_metabolic_cardio_training",
        HKWorkoutActivityType.cardioDance.rawValue: "cardio_dance",
        HKWorkoutActivityType.socialDance.rawValue: "social_dance",
        HKWorkoutActivityType.other.rawValue: "other"
    ]

    static func snakeCase(_ activity: HKWorkoutActivityType) -> String {
        if let slug = snakeCaseByRawValue[activity.rawValue] {
            return slug
        }
        return legacySnakeCase(from: activity) ?? "activity_\(activity.rawValue)"
    }

    static func displayName(for activity: HKWorkoutActivityType) -> String {
        snakeCase(activity)
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Pre-iOS 18 `String(describing:)` returned `HKWorkoutActivityType.running`.
    private static func legacySnakeCase(from activity: HKWorkoutActivityType) -> String? {
        let described = String(describing: activity)
        guard described.hasPrefix("HKWorkoutActivityType.") else { return nil }
        let caseName = String(described.dropFirst("HKWorkoutActivityType.".count))
        guard !caseName.contains("(") else { return nil }
        return caseName.camelCaseToSnakeCase()
    }
}

private extension String {
    func camelCaseToSnakeCase() -> String {
        var result = ""
        for scalar in unicodeScalars {
            let s = String(scalar)
            if CharacterSet.uppercaseLetters.contains(scalar), !result.isEmpty {
                result += "_"
            }
            result += s.lowercased()
        }
        return result
    }
}
