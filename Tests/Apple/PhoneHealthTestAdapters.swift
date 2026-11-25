import Foundation
import WristlabCore

enum SyntheticPhoneFailure: Error { case authorization, query }

@MainActor final class HealthKitReader {
    var authorizations = 0
    var reads = 0
    var cancellations = 0
    var authorizationFailure = false
    var queryFailure = false
    var holdAuthorization = false
    var holdReads = false
    var ignoreCancellation = false
    var authorizationWaiters: [CheckedContinuation<Void, any Error>] = []
    var readWaiters: [CheckedContinuation<RecordBatch, any Error>] = []
    var observer: (@Sendable () async -> Void)?
    var records: [HealthRecord] = []
    var inputAnchors: [[String: Data]] = []
    func authorize() async throws {
        authorizations += 1
        if authorizationFailure { throw SyntheticPhoneFailure.authorization }
        if holdAuthorization {
            try await withCheckedThrowingContinuation { authorizationWaiters.append($0) }
        }
    }
    func authorizeMoods() async throws {}
    func readMoods(from start: Date) async throws -> [MoodEntry] { [] }
    func observe(onChange: @escaping @Sendable () async -> Void) { observer = onChange }
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        reads += 1
        inputAnchors.append(state.anchors)
        if !ignoreCancellation { try Task.checkCancellation() }
        if queryFailure { throw SyntheticPhoneFailure.query }
        if holdReads {
            let result = try await withCheckedThrowingContinuation { readWaiters.append($0) }
            if !ignoreCancellation { try Task.checkCancellation() }
            if queryFailure { throw SyntheticPhoneFailure.query }
            return result
        }
        return batch()
    }
    func batch() -> RecordBatch { RecordBatch(additions: records, anchors: ["heartRate": Data([1])]) }
    func releaseAuthorization() {
        let waiters = authorizationWaiters
        authorizationWaiters = []
        for waiter in waiters { waiter.resume() }
    }
    func releaseReads() {
        let waiters = readWaiters
        readWaiters = []
        for waiter in waiters { waiter.resume(returning: batch()) }
    }
    func cancelRead() {
        cancellations += 1
        guard !ignoreCancellation else { return }
        let waiters = readWaiters
        readWaiters = []
        for waiter in waiters { waiter.resume(throwing: CancellationError()) }
    }
    func stop() { cancelRead(); observer = nil }
}

@MainActor final class WatchBridge {
    var onPrepareSnapshot: (() async -> Void)?
    var onRefresh: (() async -> WatchRefreshOutcome)?
    func publish(_ snapshot: DisplaySnapshot) {}
}

@MainActor enum PhoneWidgetStore {
    static func publish(_ snapshot: DisplaySnapshot) {}
}
