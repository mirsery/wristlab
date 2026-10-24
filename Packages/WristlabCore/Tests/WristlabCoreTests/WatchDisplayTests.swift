import Foundation
import Testing
@testable import WristlabCore

struct WatchDisplayTests {
    private func snapshot() throws -> DisplaySnapshot {
        var value = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-phone", epoch: 1, sequence: 1)
        value.source = .healthKit
        return value
    }
    @Test func initialAndLegacyMigration_TC_WSOURCE_001() throws {
        #expect(try WatchDisplayEnvelope.migrate(phone: nil).mode == nil)
        let phone = try snapshot()
        let envelope = try WatchDisplayEnvelope.migrate(phone: phone)
        #expect(envelope.mode == .phone)
        #expect(envelope.snapshot == phone)
        #expect(envelope.localState == .notConnected)
    }
    @Test func localSelectionNeverMixesPhone_TC_WSOURCE_002() throws {
        var envelope = try WatchDisplayEnvelope.migrate(phone: snapshot())
        envelope = try envelope.selecting(.local, snapshot: nil)
        #expect(envelope.snapshot == nil)
        #expect(envelope.originTitle == "手表本地计算")
        let projected = try envelope.projecting(snapshot(), from: .phone)
        #expect(projected == envelope)
    }
    @Test func stopMarkerIsDurableAndRejectsProjection_TC_WLOCAL_004() throws {
        let initial = try WatchDisplayEnvelope.migrate(phone: nil).selecting(.local, snapshot: nil)
        let stopped = try initial.stoppingLocal()
        let reopened = try WatchDisplayEnvelope.decode(JSONEncoder().encode(stopped))
        #expect(reopened.localState == .stopped)
        #expect(reopened.cleanupPending)
        #expect(reopened.snapshot == nil)
        #expect(throws: DomainError.self) { try reopened.projecting(snapshot(), from: .local) }
    }
    @Test func displayRejectsDemoAndUnknownSchema_TC_WSOURCE_005() throws {
        var demo = try snapshot()
        demo.source = .demo
        #expect(throws: DomainError.self) { try WatchDisplayEnvelope.migrate(phone: demo) }
        var envelope = try WatchDisplayEnvelope.migrate(phone: nil)
        envelope.schemaVersion = 99
        #expect(throws: DomainError.self) { try envelope.validate() }
    }
    @Test func phoneClearPreservesLocalReport_TC_WSOURCE_004() throws {
        var local = try snapshot()
        local.producerID = "synthetic-local"
        let initial = try WatchDisplayEnvelope.migrate(phone: nil).enablingLocal()
        let envelope = try initial.selecting(.local, snapshot: local)
        var cleared = try snapshot()
        cleared.clearData = true
        cleared.readiness = MetricEstimate(); cleared.stress = MetricEstimate()
        cleared.energy = MetricEstimate(); cleared.exertion = MetricEstimate(); cleared.sleepMinutes = nil
        #expect(try envelope.projecting(cleared, from: .phone) == envelope)
    }
    @Test func corruptedProjectionDoesNotUseLegacyCache_TC_WSOURCE_005() throws {
        var receiver = SnapshotReceiver()
        try receiver.accept(snapshot(), confirmProducer: true)
        let legacy = try JSONEncoder().encode(receiver)
        #expect(WatchDisplayCache.read(displayData: Data("broken".utf8), legacyPhoneData: legacy) == nil)
        #expect(WatchDisplayCache.read(displayData: nil, legacyPhoneData: legacy)?.mode == .phone)
    }
    @Test func pagedDeletionWinsAndReadLimitIsBounded_TC_WLOCAL_005() throws {
        let records = Array(try DemoData.records(asOf: DemoData.previewDate).prefix(2))
        var buffer = HealthReadBuffer(maximumRecords: 4)
        try buffer.append(records, deleted: [])
        try buffer.append([], deleted: [records[0].id])
        #expect(buffer.recordsForCommit.map(\.id) == [records[1].id])
        #expect(throws: DomainError.self) { try buffer.append(records, deleted: []) }
        #expect(buffer.recordsForCommit.map(\.id) == [records[1].id])
    }
}
