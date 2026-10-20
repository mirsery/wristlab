import Foundation
import HealthKit

@MainActor
final class HealthKitReader {
    struct HRVReading: Sendable {
        let milliseconds: Double
        let date: Date
    }
    enum ReadError: Error { case unavailable }
    private let store = HKHealthStore()

    func requestAndReadLatestHRV() async throws -> HRVReading? {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        else { throw ReadError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [type])
        // Authorization completion says nothing about permission to READ individual types.
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: store)
        return samples.first.map {
            HRVReading(milliseconds: $0.quantity.doubleValue(for: .secondUnit(with: .milli)), date: $0.endDate)
        }
    }
}
