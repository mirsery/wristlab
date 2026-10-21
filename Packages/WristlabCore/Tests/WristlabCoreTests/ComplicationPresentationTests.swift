import Foundation
import Testing
@testable import WristlabCore

private let faceNow = Date(timeIntervalSince1970: 1_792_502_400)
private func faceSnapshot() throws -> DisplaySnapshot {
    var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-face-tests", epoch: 1, sequence: 1)
    snapshot.source = .healthKit // All samples remain synthetic; exercise the real-mode contract.
    snapshot.computedAt = faceNow
    snapshot.asOf = faceNow
    snapshot.energy = MetricEstimate(76, quality: .partial, effectiveAt: faceNow, validUntil: faceNow.addingTimeInterval(900))
    snapshot.readiness = MetricEstimate(89, effectiveAt: faceNow, validUntil: faceNow.addingTimeInterval(7200))
    snapshot.stress = MetricEstimate(39, effectiveAt: faceNow, validUntil: faceNow.addingTimeInterval(300))
    return snapshot
}

// TC-FACE-002/003/005
@Test func complicationKeepsMetricIdentityPartialQualityAndRealZero() throws {
    var snapshot = try faceSnapshot()
    #expect(ComplicationMetric.allCases.map { ComplicationPresentation(snapshot: snapshot, metric: $0, at: faceNow).value } == [76, 89, 39])
    let partial = ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow)
    #expect(partial.state == .partial)
    #expect(partial.statusText == "部分估算")
    #expect(partial.updatedAt == faceNow)
    snapshot.energy = MetricEstimate(0)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow).value == 0)
}

// TC-FACE-004
@Test func complicationMapsMissingAvailabilityWithoutZeroGauges() throws {
    var snapshot = try faceSnapshot()
    let states: [(Availability, ComplicationState)] = [(.calibrating, .calibrating), (.insufficientData, .insufficientData), (.unsupported, .unsupported), (.failed, .failed)]
    for (availability, expected) in states {
        snapshot.energy = MetricEstimate(availability: availability, baselineDays: 7)
        let view = ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow)
        #expect(view.value == nil)
        #expect(view.state == expected)
        #expect(ComplicationPresentation(snapshot: snapshot, metric: .readiness, at: faceNow).value == 89)
    }
}

// TC-FACE-006
@Test func complicationExpiryUsesIndependentStrictBoundaries() throws {
    var snapshot = try faceSnapshot()
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow.addingTimeInterval(900)).value == 76)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow.addingTimeInterval(901)).state == .stale)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow.addingTimeInterval(901)).value == nil)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .readiness, at: faceNow.addingTimeInterval(3600)).value == 89)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .readiness, at: faceNow.addingTimeInterval(3601)).value == nil)
    snapshot.computedAt = faceNow.addingTimeInterval(1)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .readiness, at: faceNow).state == .stale)
    snapshot.computedAt = faceNow
    snapshot.energy.effectiveAt = faceNow.addingTimeInterval(1)
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow).value == nil)
}

// TC-FACE-007/008, TC-ENERGY-001/002
@Test func complicationCacheValidationClearAndDemoIsolation() throws {
    var snapshot = try faceSnapshot()
    #expect(ComplicationPresentation(snapshot: nil, metric: .energy, at: faceNow).state == .awaitingSync)
    #expect(ComplicationCache.snapshot(from: Data("not JSON".utf8)) == nil)
    var receiver = SnapshotReceiver()
    try receiver.accept(snapshot, confirmProducer: true)
    #expect(ComplicationCache.snapshot(from: try JSONEncoder().encode(receiver)) == snapshot)
    snapshot.source = .demo
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow).value == nil)
    let demoCache = try JSONEncoder().encode(["snapshot": snapshot])
    #expect(ComplicationCache.snapshot(from: demoCache) == nil)
    snapshot.source = .healthKit; snapshot.schemaVersion = 99
    #expect(ComplicationPresentation(snapshot: snapshot, metric: .energy, at: faceNow).value == nil)
    snapshot.schemaVersion = 1; snapshot.epoch = 2; snapshot.clearData = true
    snapshot.energy = MetricEstimate(); snapshot.readiness = MetricEstimate(); snapshot.stress = MetricEstimate(); snapshot.exertion = MetricEstimate(); snapshot.sleepMinutes = nil
    try receiver.accept(snapshot)
    let cleared = ComplicationCache.snapshot(from: try JSONEncoder().encode(receiver))
    #expect(ComplicationPresentation(snapshot: cleared, metric: .energy, at: faceNow).state == .cleared)
}

// TC-FACE-009
@Test func complicationTimelinePreparesDistinctExpirationTransitions() throws {
    var snapshot = try faceSnapshot()
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow) == [0,301,901,3601,7201].map { faceNow.addingTimeInterval(Double($0)) })
    snapshot.stress.validUntil = snapshot.energy.validUntil
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow).count == 4)
    #expect(ComplicationTimeline.dates(snapshot: nil, now: faceNow) == [faceNow])
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow.addingTimeInterval(902)).allSatisfy { $0 >= faceNow.addingTimeInterval(902) })
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow.addingTimeInterval(3601)) == [faceNow.addingTimeInterval(3601)])
    snapshot.computedAt = faceNow.addingTimeInterval(1)
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow) == [faceNow])
    snapshot = try faceSnapshot(); snapshot.clearData = true
    snapshot.energy = MetricEstimate(); snapshot.readiness = MetricEstimate(); snapshot.stress = MetricEstimate(); snapshot.exertion = MetricEstimate(); snapshot.sleepMinutes = nil
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow) == [faceNow])
    snapshot = try faceSnapshot(); snapshot.source = .demo
    #expect(ComplicationTimeline.dates(snapshot: snapshot, now: faceNow) == [faceNow])
}

// TC-FACE-011
@Test func complicationRoutesRoundTripAndPreserveExistingEnergyKind() {
    for route in ComplicationDestination.allCases {
        #expect(ComplicationDestination(url: route.url) == route)
    }
    #expect(ComplicationDestination.energy.metric == .energy)
    #expect(ComplicationDestination.overview.metric == nil)
    #expect(ComplicationMetric.energy.widgetKind == "WristlabEnergy")
    #expect(Set(ComplicationMetric.allCases.map(\.widgetKind)).count == 3)
}

// TC-FACE-012
@Test(arguments: [
    "https://complication/energy", "wristlab://other/energy", "wristlab://complication/unknown",
    "wristlab://complication/energy?score=99", "wristlab://complication/stress#fake",
    "wristlab://user@complication/energy", "wristlab://complication:80/energy",
    "wristlab://complication/%65nergy", "wristlab://complication/energy/extra"
])
func complicationUnknownOrInjectedURLsReturnToOverview(_ value: String) throws {
    #expect(ComplicationDestination(url: try #require(URL(string: value))) == .overview)
}
