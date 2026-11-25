import Foundation
import Testing
@testable import WristlabCore

struct WatchRefreshTests {
    @Test func requestWaitsForReplyAndCoalesces() {
        var state = WatchRefreshState()
        let request = UUID()
        let started = state.begin(request, reachable: true, activated: true)
        #expect(started)
        #expect(state.phase == .waiting)
        let duplicated = state.begin(UUID(), reachable: true, activated: true)
        #expect(!duplicated)
        #expect(state.requestID == request)
    }

    @Test func unavailableDoesNotPretendRequestSucceeded() {
        var state = WatchRefreshState()
        let unreachable = state.begin(UUID(), reachable: false, activated: true)
        #expect(!unreachable)
        #expect(state.phase == .unreachable)
        let inactive = state.begin(UUID(), reachable: true, activated: false)
        #expect(!inactive)
        #expect(state.phase == .activationFailed)
    }

    @Test func timeoutAndLateReplyAreIsolated() {
        var state = WatchRefreshState()
        let first = UUID()
        let firstStarted = state.begin(first, reachable: true, activated: true)
        #expect(firstStarted)
        state.complete(first, phase: .timedOut)
        let second = UUID()
        let secondStarted = state.begin(second, reachable: true, activated: true)
        #expect(secondStarted)
        state.complete(first, phase: .failed)
        #expect(state.phase == .waiting)
        state.complete(second, phase: .noSnapshot)
        #expect(state.phase == .noSnapshot)
        #expect(state.requestID == nil)
    }

    @Test func repliesRoundTripWithoutAssumingSnapshotReceipt() throws {
        for outcome in [WatchRefreshOutcome.noSnapshot, .needsHealthConnection, .failed, .snapshotAvailable] {
            let reply = WatchRefreshReply(requestID: UUID(), outcome: outcome, snapshot: nil)
            let decoded = try JSONDecoder().decode(WatchRefreshReply.self, from: JSONEncoder().encode(reply))
            #expect(decoded == reply)
        }
    }

    @Test @MainActor func cachedSnapshotRepliesBeforeSlowOrFailedRefresh() async {
        var refreshed = false
        var responses: [WatchRefreshReply] = []
        let cached = Data([1, 2, 3])
        let requestID = UUID()
        await WatchRefreshResponder.respond(requestID: requestID, cached: { cached }, refresh: {
            #expect(responses.count == 1)
            refreshed = true
            return .failed
        }, reply: { response in
            #expect(!refreshed)
            responses.append(response)
        })
        #expect(refreshed)
        #expect(responses == [WatchRefreshReply(requestID: requestID, outcome: .snapshotAvailable, snapshot: cached)])
    }

    @Test @MainActor func emptyPhoneReturnsExplicitResultOrNewSnapshot() async {
        for result in [WatchRefreshOutcome.noSnapshot, .needsHealthConnection, .failed, .snapshotAvailable] {
            var cached: Data?
            var responses: [WatchRefreshReply] = []
            await WatchRefreshResponder.respond(requestID: UUID(), cached: { cached }, refresh: {
                if result == .snapshotAvailable { cached = Data([4]) }
                return result
            }, reply: { responses.append($0) })
            #expect(responses.count == 1)
            #expect(responses.first?.outcome == result)
            #expect(responses.first?.snapshot == cached)
        }
    }

    @Test @MainActor func coldPhoneLoadsStoredSnapshotBeforeRefreshing() async {
        var prepared = false
        var replied = false
        await WatchRefreshResponder.respond(requestID: UUID(), cached: {
            await Task.yield()
            prepared = true
            return Data([5])
        }, refresh: {
            #expect(prepared && replied)
            return .failed
        }, reply: { response in
            replied = true
            #expect(response.snapshot == Data([5]))
        })
    }

    @Test func deliveryCommitsOnlyAfterSuccessfulPersistence() throws {
        enum SaveFailure: Error { case unavailable }
        var receiver = SnapshotReceiver()
        var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic", epoch: 1, sequence: 1)
        snapshot.source = .healthKit
        var persisted = Data()
        try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: true) { persisted = $0 }
        let reopened = try JSONDecoder().decode(SnapshotReceiver.self, from: persisted)
        #expect(reopened.snapshot == snapshot)
        snapshot.sequence = 2
        #expect(throws: SaveFailure.self) {
            try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: false) { _ in throw SaveFailure.unavailable }
        }
        #expect(receiver.snapshot?.sequence == 1)
    }

    @Test func deliveryRejectsDemoOldRevisionAndUnconfirmedProducer() throws {
        var receiver = SnapshotReceiver()
        var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic", epoch: 1, sequence: 2)
        #expect(throws: DomainError.self) {
            try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: true) { _ in Issue.record("Invalid snapshot persisted") }
        }
        snapshot.source = .healthKit
        try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: true) { _ in }
        snapshot.sequence = 1
        #expect(throws: DomainError.self) {
            try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: false) { _ in Issue.record("Old revision persisted") }
        }
        snapshot.producerID = "other-synthetic"
        #expect(throws: DomainError.producerConfirmationRequired) {
            try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: false) { _ in Issue.record("Unconfirmed producer persisted") }
        }
    }
}
