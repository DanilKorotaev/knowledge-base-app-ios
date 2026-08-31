import Foundation
import HealthKit

/// Reads statistics and samples from HealthKit for daily aggregation (same store instance as authorization).
protocol DailyHealthKitDataProviding: AnyObject {
    func statistics(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics?

    func quantitySamples(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date
    ) async throws -> [HKQuantitySample]

    func categorySamples(
        for categoryType: HKCategoryType,
        from start: Date,
        to end: Date
    ) async throws -> [HKCategorySample]
}

extension HealthStoreAdapter: DailyHealthKitDataProviding {
    func statistics(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
            execute(query: query)
        }
    }

    func quantitySamples(
        for quantityType: HKQuantityType,
        from start: Date,
        to end: Date
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            execute(query: query)
        }
    }

    func categorySamples(
        for categoryType: HKCategoryType,
        from start: Date,
        to end: Date
    ) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            execute(query: query)
        }
    }
}
