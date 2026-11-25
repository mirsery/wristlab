import Foundation
import Testing
@testable import WristlabCore

@MainActor struct HealthBatchLoaderTests {
    @Test func pagesCommitLastAnchorAndDeletionWins_TC_WLOCAL_005() async throws {
        let record = try #require(DemoData.records(asOf: DemoData.previewDate).first)
        var calls = 0
        let batch = try await HealthBatchLoader.load(kinds: [.heartRate], anchors: [:], replaceAll: true, queryStart: DemoData.previewDate) { _, anchor in
            calls += 1
            if calls == 1 {
                #expect(anchor == nil)
                return HealthRecordPage(records: [record], deleted: [], anchor: Data([1]), count: 500)
            }
            #expect(anchor == Data([1]))
            return HealthRecordPage(records: [], deleted: [record.id], anchor: Data([2]), count: 1)
        }
        #expect(calls == 2)
        #expect(batch.additions.isEmpty)
        #expect(batch.deletions == [record.id])
        #expect(batch.anchors[HealthKind.heartRate.rawValue] == Data([2]))
    }
    @Test func failedSecondPageAndRepeatedAnchorNeverReturnPartialBatch_TC_WLOCAL_005() async throws {
        enum Failure: Error { case page }
        for repeats in [false, true] {
            var calls = 0
            do {
                _ = try await HealthBatchLoader.load(kinds: [.hrv], anchors: [:], replaceAll: true, queryStart: .distantPast) { _, _ in
                    calls += 1
                    if calls == 2, !repeats { throw Failure.page }
                    return HealthRecordPage(records: [], deleted: [], anchor: Data([1]), count: 500)
                }
                Issue.record("Partial batch or repeated anchor escaped")
            } catch {
                #expect(calls == 2)
                #expect(error is Failure || error is DomainError)
            }
        }
    }
    @Test func cancellationAfterPageDoesNotStartNextPage_TC_WLOCAL_005() async throws {
        var continuation: CheckedContinuation<HealthRecordPage, any Error>?
        var calls = 0
        let task = Task {
            try await HealthBatchLoader.load(kinds: [.hrv], anchors: [:], replaceAll: true, queryStart: .distantPast) { _, _ in
                calls += 1
                return try await withCheckedThrowingContinuation { continuation = $0 }
            }
        }
        while continuation == nil { await Task.yield() }
        task.cancel()
        continuation?.resume(returning: HealthRecordPage(records: [], deleted: [], anchor: Data([1]), count: 500))
        do { _ = try await task.value; Issue.record("Cancelled batch escaped") }
        catch { #expect(error is CancellationError) }
        #expect(calls == 1)
    }
    @Test func readerInvalidationAfterSuccessfulCallbackStopsPaging_TC_WLOCAL_005() async throws {
        var cancelled = false
        var calls = 0
        do {
            _ = try await HealthBatchLoader.load(kinds: [.hrv], anchors: [:], replaceAll: true, queryStart: .distantPast,
                isCancelled: { cancelled }) { _, _ in
                    calls += 1
                    cancelled = true
                    return HealthRecordPage(records: [], deleted: [], anchor: Data([1]), count: 500)
                }
            Issue.record("Invalidated reader continued")
        } catch { #expect(error is CancellationError) }
        #expect(calls == 1)
    }
}
