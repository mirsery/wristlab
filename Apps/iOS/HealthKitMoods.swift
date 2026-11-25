import Foundation
@preconcurrency import HealthKit
import WristlabCore

extension HealthKitReader {
    func authorizeMoods() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw ReadError.unavailable }
        if #available(iOS 18.0, *) { try await store.requestAuthorization(toShare: [], read: [HKObjectType.stateOfMindType()]) }
    }
    func readMoods(from start: Date) async throws -> [MoodEntry] {
        guard #available(iOS 18.0, *), HKHealthStore.isHealthDataAvailable() else { return [] }
        let descriptor = HKSampleQueryDescriptor(predicates: [.stateOfMind(HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 500)
        return try await descriptor.result(for: store).compactMap { sample in
            guard let kind = MoodKind(rawValue: sample.kind.rawValue) else { return nil }
            return MoodEntry(id: sample.uuid.uuidString, at: sample.startDate, kind: kind,
                valence: sample.valence, classification: sample.valenceClassification.rawValue,
                labels: sample.labels.map(\.rawValue), associations: sample.associations.map(\.rawValue))
        }
    }
}
