import Foundation
@preconcurrency import HealthKit
import WristlabCore

@MainActor
final class HealthKitReader {
    enum ReadError: Error { case unavailable, missingAnchor }
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var queries: [HKQuery] = []
    private static var types: [(HealthKind, HKSampleType)] {
        [(.heartRate, HKQuantityType(.heartRate)), (.restingHeartRate, HKQuantityType(.restingHeartRate)),
         (.hrv, HKQuantityType(.heartRateVariabilitySDNN)), (.sleep, HKCategoryType(.sleepAnalysis)), (.workout, HKObjectType.workoutType())]
    }
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw ReadError.unavailable }
        try await store.requestAuthorization(toShare: [], read: Set(Self.types.map { $0.1 }))
    }
    /// Self-reported moods are read on their own: they are not scoring inputs and never touch the anchors.
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
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        do { return try await queryBatch(state: state, asOf: asOf) }
        catch {
            guard !state.anchors.isEmpty else { throw error }
            var reset = state; reset.anchors = [:]
            return try await queryBatch(state: reset, asOf: asOf)
        }
    }
    private func queryBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        defer { queries.removeAll() }
        guard HKHealthStore.isHealthDataAvailable() else { throw ReadError.unavailable }
        let clock = try AnalysisClock(timeZoneID: state.profile.timeZoneID)
        let invalidAnchor = state.anchors.values.contains { data in
            (try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)) == nil
        }
        let fullReload = state.queryStart == nil || state.anchors.count != Self.types.count || invalidAnchor
        let start = state.queryStart ?? clock.shiftedDay(asOf, by: state.records.isEmpty ? -61 : -151)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        var additions: [HealthRecord] = [], deletions = Set<String>(), anchors: [String: Data] = [:]
        for (kind, type) in Self.types {
            try Task.checkCancellation()
            let old = fullReload ? nil : state.anchors[kind.rawValue]
            let anchor = try old.map { try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }.flatMap { $0 }
            let result: QueryResult = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { _, samples, deleted, newAnchor, error in
                    if let error { continuation.resume(throwing: error); return }
                    do {
                        guard let newAnchor else { throw ReadError.missingAnchor }
                        let encoded = try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                        continuation.resume(returning: QueryResult(records: (samples ?? []).compactMap { Self.convert($0, kind: kind) }, deleted: Set((deleted ?? []).map { $0.uuid.uuidString }), anchor: encoded))
                    } catch { continuation.resume(throwing: error) }
                }
                queries.append(query); store.execute(query)
            }
            additions += result.records; deletions.formUnion(result.deleted); anchors[kind.rawValue] = result.anchor
        }
        queries.removeAll()
        return RecordBatch(additions: additions, deletions: deletions, anchors: anchors, replaceAll: fullReload, queryStart: start)
    }
    func observe(onChange: @escaping @Sendable () async -> Void) {
        guard observers.isEmpty else { return }
        for (_, type) in Self.types {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                let token = ObserverCompletion(completion)
                Task { await onChange(); token.finish() }
            }
            observers.append(query); store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
    func stop() {
        for query in observers { store.stop(query) }
        observers.removeAll()
        // In-flight read continuations finish normally; the model rejects their generation on clear.
        for (_, type) in Self.types { store.disableBackgroundDelivery(for: type) { _, _ in } }
    }
    private struct QueryResult: Sendable { var records: [HealthRecord]; var deleted: Set<String>; var anchor: Data }
    nonisolated private static func convert(_ sample: HKSample, kind: HealthKind) -> HealthRecord? {
        let product = sample.sourceRevision.productType ?? sample.device?.model ?? "Other"
        let family = product.lowercased().contains("watch") ? "Watch" : product.lowercased().contains("iphone") ? "iPhone" : product
        let rank = family == "Watch" ? 0 : family == "iPhone" ? 2 : 1
        let source = SampleSource(bundle: sample.sourceRevision.source.bundleIdentifier, family: family, device: sample.device?.localIdentifier ?? "", rank: rank)
        var record = HealthRecord(id: sample.uuid.uuidString, kind: kind, start: sample.startDate, end: sample.endDate, source: source,
                                  manual: (sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber)?.boolValue ?? false,
                                  version: (sample.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.intValue ?? 0)
        if let quantity = sample as? HKQuantitySample {
            record.value = quantity.quantity.doubleValue(for: kind == .hrv ? .secondUnit(with: .milli) : HKUnit.count().unitDivided(by: .minute()))
        } else if let category = sample as? HKCategorySample, let phase = HKCategoryValueSleepAnalysis(rawValue: category.value) {
            switch phase {
            case .inBed: record.stage = .inBed
            case .awake: record.stage = .awake
            case .asleepCore: record.stage = .core
            case .asleepDeep: record.stage = .deep
            case .asleepREM: record.stage = .rem
            case .asleepUnspecified: record.stage = .unspecified
            @unknown default: record.stage = .unknown
            }
        } else if let workout = sample as? HKWorkout { record.workoutType = String(workout.workoutActivityType.rawValue) }
        return record
    }
}

// HealthKit permits completion on any queue. This box transfers the SDK callback
// across concurrency domains and guarantees that it is invoked at most once.
private final class ObserverCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: (() -> Void)?
    init(_ completion: @escaping () -> Void) { self.completion = completion }
    func finish() {
        lock.lock(); let callback = completion; completion = nil; lock.unlock()
        callback?()
    }
}
