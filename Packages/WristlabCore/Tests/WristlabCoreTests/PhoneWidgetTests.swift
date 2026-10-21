import Foundation
import Testing
@testable import WristlabCore

private func realSnapshot() throws -> DisplaySnapshot {
    var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-phone", epoch: 1, sequence: 3)
    snapshot.source = .healthKit
    return snapshot
}

// TC-PHONEW-001: only valid real snapshots and clear markers are accepted.
@Test func phoneWidgetCacheAcceptsOnlyRealSnapshots_TC_PHONEW_001() throws {
    let real = try realSnapshot()
    #expect(PhoneWidgetCache.snapshot(from: try real.encoded()) == real)
    #expect(PhoneWidgetCache.snapshot(from: nil) == nil)
    #expect(PhoneWidgetCache.snapshot(from: Data("{".utf8)) == nil)
    #expect(PhoneWidgetCache.snapshot(from: Data(repeating: 32, count: 65_537)) == nil)
    var demo = real
    demo.source = .demo
    #expect(PhoneWidgetCache.snapshot(from: try JSONEncoder().encode(demo)) == nil)
    var json = try #require(JSONSerialization.jsonObject(with: real.encoded()) as? [String: Any])
    json["schemaVersion"] = 99
    #expect(PhoneWidgetCache.snapshot(from: try JSONSerialization.data(withJSONObject: json)) == nil)
    // A clear marker stays so the widget can say the data was cleared.
    var cleared = real
    cleared.clearData = true
    cleared.readiness = MetricEstimate(); cleared.stress = MetricEstimate(); cleared.energy = MetricEstimate(); cleared.exertion = MetricEstimate()
    cleared.sleepMinutes = nil
    #expect(PhoneWidgetCache.snapshot(from: try cleared.encoded())?.clearData == true)
}

// TC-PHONEW-002: the summary follows the shared complication rules and the timeline refreshes at expirations.
@Test func phoneWidgetTimelineAndStatesFollowSnapshot_TC_PHONEW_002() throws {
    let snapshot = try realSnapshot()
    let now = snapshot.computedAt
    let summary = PhoneWidgetSummary(snapshot: snapshot, at: now)
    #expect(summary.metrics.map(\.metric) == [.readiness, .energy, .stress])
    for metric in summary.metrics {
        #expect(metric == ComplicationPresentation(snapshot: snapshot, metric: metric.metric, at: now))
    }
    #expect(summary.metrics[0].value == 89)
    #expect(summary.updatedAt == snapshot.computedAt)
    #expect(summary.dates(now: now) == ComplicationTimeline.dates(snapshot: snapshot, now: now))
    #expect(summary.dates(now: now).allSatisfy { $0 >= now })
    // Past every validity window the values disappear and the state says so.
    let later = now.addingTimeInterval(3 * 86400)
    #expect(PhoneWidgetSummary(snapshot: snapshot, at: later).metrics.allSatisfy { $0.value == nil && $0.state == .stale })
    // No file: waiting for the phone; clear marker: cleared, no values.
    #expect(PhoneWidgetSummary(snapshot: nil, at: now).metrics.allSatisfy { $0.state == .awaitingSync && $0.value == nil })
    // A valid clear marker carries no values (an invalid one would read as waiting).
    var cleared = snapshot
    cleared.clearData = true
    cleared.readiness = MetricEstimate(); cleared.stress = MetricEstimate(); cleared.energy = MetricEstimate(); cleared.exertion = MetricEstimate()
    cleared.sleepMinutes = nil
    #expect(PhoneWidgetSummary(snapshot: cleared, at: now).metrics.allSatisfy { $0.state == .cleared && $0.value == nil })
}
