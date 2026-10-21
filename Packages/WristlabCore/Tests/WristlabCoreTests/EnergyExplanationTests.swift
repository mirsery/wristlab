import Foundation
import Testing
@testable import WristlabCore

// TC-EXPLAIN-001: real energy seeding failure must report the actual baseline.
@Test func energyInsufficientNightBaselineExplainsProgress() throws {
    let now = DemoData.previewDate, clock = try AnalysisClock(timeZoneID: "UTC")
    let cutoff = clock.shiftedDay(now, by: -13)
    let records = try DemoData.records(asOf: now).filter { $0.end >= cutoff }
    let report = try HealthEngine.evaluate(records: records, profile: HealthProfile(timeZoneID: "UTC"), asOf: now, inputRevision: 1)
    #expect(report.energy.estimate.value == nil)
    #expect(report.energy.estimate.availability == .calibrating)
    #expect(report.energy.estimate.baselineDays == 13)
    #expect(report.energy.estimate.reasons.contains("baselineNotReady"))
    #expect(!report.energy.estimate.reasons.contains("missingPrimarySleep"))
}

// TC-EXPLAIN-002: actual missing inputs remain separate from history length.
@Test func energyDistinguishesMissingNightInputs() throws {
    let now = DemoData.previewDate, records = try DemoData.records(asOf: now)
    for (missingKind, reason) in [(HealthKind.sleep, "missingPrimarySleep"), (.hrv, "missingCurrentHRV"), (.restingHeartRate, "missingCurrentRHR")] {
        let report = try HealthEngine.evaluate(records: records.filter { $0.kind != missingKind }, profile: HealthProfile(timeZoneID: "UTC"), asOf: now, inputRevision: 1)
        #expect(report.energy.estimate.value == nil)
        #expect(report.energy.estimate.reasons.contains(reason))
    }
}

// TC-EXPLAIN-003: one shared explanation and unchanged snapshot schema.
@Test func explanationProgressSurvivesSnapshotRoundTripAndWatchMapping() throws {
    let now = DemoData.previewDate
    let metric = MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: 7, mode: "energy")
    let message = MetricExplanation(metric, at: now)
    #expect(message.summary.contains("7/14"))
    #expect(message.summary.contains("夜间基线不足"))
    #expect(message.detail.contains("不要求连续"))
    #expect(message.displayValue == nil)
    var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-explanations", epoch: 0, sequence: 1)
    snapshot.source = .healthKit; snapshot.energy = metric
    let decoded = try DisplaySnapshot.decode(snapshot.encoded())
    let watch = ComplicationPresentation(snapshot: decoded, metric: .energy, at: now)
    #expect(watch.statusText == message.summary)
    #expect(watch.detailText == message.detail)
    #expect(watch.value == nil)
}

// TC-EXPLAIN-004: missing/expired/unknown are neutral and real zero survives.
@Test func explanationSeparatesMissingStaleCoverageAndRealZero() throws {
    let now = DemoData.previewDate
    let missing = MetricExplanation(MetricEstimate(reasons: ["missingHR"]), at: now)
    #expect(missing.summary.contains("心率"))
    #expect(missing.detail.contains("来源优先级"))
    let low = MetricExplanation(MetricEstimate(reasons: ["lowCoverage"], mode: "energy", coverage: 0.6), at: now)
    #expect(low.summary.contains("80%"))
    #expect(low.detail.contains("60%"))
    let unknown = MetricExplanation(MetricEstimate(reasons: ["unknown-future-reason"]), at: now)
    #expect(unknown.summary == "等待更多记录")
    #expect(unknown.detail.contains("不能证明读取权限被拒绝"))
    let zero = MetricExplanation(MetricEstimate(0, validUntil: now.addingTimeInterval(60)), at: now)
    #expect(zero.displayValue == 0)
    let expired = MetricExplanation(MetricEstimate(0, validUntil: now.addingTimeInterval(-1)), at: now)
    #expect(expired.displayValue == nil)
    #expect(expired.summary == "数据已过期")
}

// TC-EXPLAIN-002: current missing inputs must not be hidden by an older failure.
@Test func energyLatestNightMissingInputOverridesEarlierCalibration() throws {
    let now = DemoData.previewDate, clock = try AnalysisClock(timeZoneID: "UTC")
    let records = try DemoData.records(asOf: now).filter { $0.end >= clock.shiftedDay(now, by: -13) }
    let today = clock.day(containing: now).start
    for (kind, reason) in [(HealthKind.hrv, "missingCurrentHRV"), (.restingHeartRate, "missingCurrentRHR")] {
        let partial = records.filter { !($0.kind == kind && $0.start >= today) }
        let report = try HealthEngine.evaluate(records: partial, profile: HealthProfile(timeZoneID: "UTC"), asOf: now, inputRevision: 1)
        #expect(report.energy.estimate.value == nil)
        #expect(report.energy.estimate.reasons == [reason])
        #expect(report.energy.estimate.availability == .insufficientData)
    }
}

// TC-EXPLAIN-004: time validity applies even when the metric has no number.
@Test func explanationMissingExpiredOrFutureInputsMatchWatchPriority() throws {
    let now = DemoData.previewDate
    let metrics = [
        MetricEstimate(reasons: ["lowCoverage"], mode: "energy", validUntil: now.addingTimeInterval(-1), coverage: 0.6),
        MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: 7, mode: "energy", effectiveAt: now.addingTimeInterval(1))
    ]
    for metric in metrics {
        let phone = MetricExplanation(metric, at: now)
        #expect(phone.summary.contains("过期"))
        #expect(phone.displayValue == nil)
        var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-missing-expiry", epoch: 0, sequence: 1)
        snapshot.source = .healthKit; snapshot.energy = metric
        let watch = ComplicationPresentation(snapshot: snapshot, metric: .energy, at: now)
        #expect(watch.state == .stale)
        #expect(watch.value == nil)
    }
}
