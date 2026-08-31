import Foundation
import HealthKit

enum WorkoutTypeSlug {
    static func snakeCase(_ activity: HKWorkoutActivityType) -> String {
        let raw = String(describing: activity).replacingOccurrences(of: "HKWorkoutActivityType.", with: "")
        return raw.camelCaseToSnakeCase()
    }

    static func displayName(for activity: HKWorkoutActivityType) -> String {
        snakeCase(activity).replacingOccurrences(of: "_", with: " ").capitalized
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
