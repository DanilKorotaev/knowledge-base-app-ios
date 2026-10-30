import CoreLocation
import Foundation
import HealthKit

enum WorkoutRouteLoader {
    static func loadRoute(for workout: HKWorkout, store: HKHealthStore) async throws -> WorkoutRouteExport? {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        guard let route = routes.first else { return nil }

        var points: [RoutePoint] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let locations {
                    for location in locations {
                        points.append(
                            RoutePoint(
                                lat: location.coordinate.latitude,
                                lon: location.coordinate.longitude,
                                timestamp: CalendarDayFormatter.iso8601UTCSeconds(from: location.timestamp),
                                altitudeM: location.altitude
                            )
                        )
                    }
                }
                if done {
                    continuation.resume(returning: ())
                }
            }
            store.execute(query)
        }

        guard !points.isEmpty else { return nil }
        return WorkoutRouteExport(points: points)
    }
}
