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
    // Size bound with otherwise valid JSON padded by trailing spaces: 32768 bytes accepted, 32769 rejected.
    let encoded = try real.encoded()
    let atLimit = encoded + Data(repeating: 32, count: PhoneWidgetCache.maximumBytes - encoded.count)
    #expect(PhoneWidgetCache.snapshot(from: atLimit) == real)
    #expect(PhoneWidgetCache.snapshot(from: atLimit + Data([32])) == nil)
    #expect(PhoneWidgetCache.maximumBytes == 32768)
    var demo = real
    demo.source = .demo
    #expect(PhoneWidgetCache.snapshot(from: try JSONEncoder().encode(demo)) == nil)
    var json = try #require(JSONSerialization.jsonObject(with: real.encoded()) as? [String: Any])
    #expect(PhoneWidgetCache.snapshot(from: try JSONSerialization.data(withJSONObject: json)) == real)
    json["schemaVersion"] = 99
    #expect(PhoneWidgetCache.snapshot(from: try JSONSerialization.data(withJSONObject: json)) == nil)
    // A clear marker that still carries values is invalid and reads as no snapshot.
    var invalidClear = real
    invalidClear.clearData = true
    #expect(PhoneWidgetCache.snapshot(from: try JSONEncoder().encode(invalidClear)) == nil)
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

// TC-PHONEW-002: per-metric states — partial, one metric expired, a missing reason, a real zero, and the phone's own wording.
@Test func phoneWidgetPerMetricStates_TC_PHONEW_002() throws {
    var snapshot = try realSnapshot()
    let now = snapshot.computedAt
    snapshot.readiness = MetricEstimate(0, mode: "night", effectiveAt: now, validUntil: now.addingTimeInterval(3600))
    snapshot.energy = MetricEstimate(60, quality: .partial, reasons: ["hrOnly"], mode: "energy", effectiveAt: now, validUntil: now.addingTimeInterval(3600))
    snapshot.stress = MetricEstimate(40, mode: "awake", effectiveAt: now.addingTimeInterval(-3600), validUntil: now.addingTimeInterval(-1))
    var calibrating = snapshot
    calibrating.readiness = MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: 9, mode: "night")
    let summary = PhoneWidgetSummary(snapshot: snapshot, at: now)
    #expect(summary.metrics[0].value == 0)
    #expect(summary.metrics[0].state == .current)
    #expect(summary.metrics[1].value == 60)
    #expect(summary.metrics[1].state == .partial)
    #expect(summary.metrics[2].value == nil)
    #expect(summary.metrics[2].state == .stale)
    #expect(summary.statusText(summary.metrics[2]) == "已过期")
    let reason = PhoneWidgetSummary(snapshot: calibrating, at: now)
    #expect(reason.metrics[0].value == nil)
    #expect(reason.statusText(reason.metrics[0]).contains("9/14"))
    let waiting = PhoneWidgetSummary(snapshot: nil, at: now)
    #expect(waiting.metrics.allSatisfy { waiting.statusText($0) == "打开Wristlab刷新" })
    // Timeline: now plus each metric's expiry, never a past moment.
    let base = try realSnapshot(), start = base.computedAt
    let full = PhoneWidgetSummary(snapshot: base, at: start)
    #expect(full.dates(now: start).map { $0.timeIntervalSince(start) } == [0, 901, 3601, 36001])
    let later = PhoneWidgetSummary(snapshot: base, at: start.addingTimeInterval(1000))
    #expect(later.dates(now: start.addingTimeInterval(1000)).map { $0.timeIntervalSince(start) } == [1000, 3601, 36001])
    #expect(later.metrics.map(\.state) == [.current, .stale, .stale])
    // A missing metric shows no value.
    var missing = base
    missing.stress = MetricEstimate(reasons: ["missingHR"], mode: "awake")
    #expect(PhoneWidgetSummary(snapshot: missing, at: start).metrics[2].value == nil)
}
