import Foundation
@preconcurrency import HealthKit
import WristlabCore

@MainActor
final class HealthKitReader {
    enum ReadError: Error { case unavailable, missingAnchor }
    let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var pendingReads: [PendingRead] = []
    private var readGeneration = UUID()
    private static var types: [(HealthKind, HKSampleType)] {
        [(.heartRate, HKQuantityType(.heartRate)), (.restingHeartRate, HKQuantityType(.restingHeartRate)),
         (.hrv, HKQuantityType(.heartRateVariabilitySDNN)), (.sleep, HKCategoryType(.sleepAnalysis)), (.workout, HKObjectType.workoutType())]
    }
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw ReadError.unavailable }
        try await store.requestAuthorization(toShare: [], read: Set(Self.types.map { $0.1 }))
    }
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        do { return try await queryBatch(state: state, asOf: asOf) }
        catch is CancellationError { throw CancellationError() }
        catch {
            guard !state.anchors.isEmpty else { throw error }
            var reset = state; reset.anchors = [:]
            return try await queryBatch(state: reset, asOf: asOf)
        }
    }
    private func queryBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        let generation = readGeneration
        guard HKHealthStore.isHealthDataAvailable() else { throw ReadError.unavailable }
        let clock = try AnalysisClock(timeZoneID: state.profile.timeZoneID)
        let invalidAnchor = state.anchors.values.contains { data in
            (try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)) == nil
        }
        let fullReload = state.queryStart == nil || state.anchors.count != Self.types.count || invalidAnchor
        let start = state.queryStart ?? clock.shiftedDay(asOf, by: state.records.isEmpty ? -61 : -151)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        #if os(watchOS)
        let maximumRecords = 200000
        #else
        let maximumRecords = Int.max
        #endif
        return try await HealthBatchLoader.load(kinds: Self.types.map { $0.0 }, anchors: state.anchors,
            replaceAll: fullReload, queryStart: start, maximumRecords: maximumRecords,
            isCancelled: { generation != self.readGeneration }) { kind, encodedAnchor in
                guard let type = Self.types.first(where: { $0.0 == kind })?.1 else { throw ReadError.unavailable }
                let anchor = try encodedAnchor.map { try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }.flatMap { $0 }
                let pending = PendingRead()
                pendingReads.append(pending)
                defer { pendingReads.removeAll { $0 === pending } }
                return try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        pending.continuation = continuation
                        guard !pending.cancelled, !Task.isCancelled else { pending.cancel(store: store); return }
                        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: HealthBatchLoader.pageSize) { _, samples, deleted, newAnchor, error in
                            let result: Result<HealthRecordPage, any Error> = Result {
                                if let error { throw error }
                                guard let newAnchor else { throw ReadError.missingAnchor }
                                let encoded = try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                                return HealthRecordPage(records: (samples ?? []).compactMap { Self.convert($0, kind: kind) },
                                    deleted: Set((deleted ?? []).map { $0.uuid.uuidString }), anchor: encoded,
                                    count: (samples?.count ?? 0) + (deleted?.count ?? 0))
                            }
                            Task { @MainActor in pending.finish(result) }
                        }
                        pending.query = query
                        store.execute(query)
                    }
                } onCancel: {
                    Task { @MainActor in pending.cancel(store: self.store) }
                }
        }
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
        cancelRead()
        for (_, type) in Self.types { store.disableBackgroundDelivery(for: type) { _, _ in } }
    }
    func cancelRead() {
        readGeneration = UUID()
        for pending in pendingReads { pending.cancel(store: store) }
    }
    @MainActor private final class PendingRead {
        var continuation: CheckedContinuation<HealthRecordPage, any Error>?
        var query: HKQuery?
        var cancelled = false
        func finish(_ result: Result<HealthRecordPage, any Error>) {
            let callback = continuation
            continuation = nil
            query = nil
            callback?.resume(with: result)
        }
        func cancel(store: HKHealthStore) {
            cancelled = true
            if let query { store.stop(query) }
            finish(.failure(CancellationError()))
        }
    }
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
        } else if let workout = sample as? HKWorkout {
            record.workoutType = String(workout.workoutActivityType.rawValue)
            record.workoutDurationSeconds = workout.duration
            let events = workout.workoutEvents ?? []
            let hasUnsupportedActivity = workout.workoutActivities.count > 1 || events.contains { $0.type == .pauseOrResumeRequest }
            let pauses = events.compactMap { event -> WorkoutPauseEvent? in
                switch event.type {
                case .pause, .motionPaused: WorkoutPauseEvent(at: event.dateInterval.start, paused: true)
                case .resume, .motionResumed: WorkoutPauseEvent(at: event.dateInterval.start, paused: false)
                default: nil
                }
            }
            if !hasUnsupportedActivity {
                record.workoutActiveIntervals = WorkoutActiveTime.intervals(start: workout.startDate, end: workout.endDate, duration: workout.duration, events: pauses)
            }
        }
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
