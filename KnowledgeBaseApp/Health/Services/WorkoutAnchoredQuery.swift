import Foundation
import HealthKit

protocol WorkoutAnchoredQueryProviding: AnyObject {
    func fetchWorkouts(anchor: HKQueryAnchor?, limit: Int) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?)
}

extension HealthStoreAdapter: WorkoutAnchoredQueryProviding {
    func fetchWorkouts(anchor: HKQueryAnchor?, limit: Int) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let type = HKObjectType.workoutType()
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: limit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: (workouts, newAnchor))
            }
            execute(query: query)
        }
    }
}
