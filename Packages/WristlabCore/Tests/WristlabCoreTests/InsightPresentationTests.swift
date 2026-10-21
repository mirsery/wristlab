import Foundation
import Testing
@testable import WristlabCore

private let insightNow = DemoData.previewDate
private func fresh(_ raw: Double?, quality: DataQuality = .complete, reasons: [String] = [], mode: String = "night",
                   contributions: [String: Double]) -> MetricEstimate {
    MetricEstimate(raw, quality: quality, reasons: reasons, baselineDays: 20, mode: mode, contributions: contributions,
                   effectiveAt: insightNow.addingTimeInterval(-60), validUntil: insightNow.addingTimeInterval(3600))
}
private let readinessInputs = ["hrv": 55.2, "baselineHRV": 48.4, "zHRV": 0.8, "rhr": 60.4, "baselineRHR": 57.2, "zRHR": -0.6]
private let stressInputs = ["hr": 82.0, "baselineHR": 70.6, "zHR": 1.4, "zHRV": 0.7]

// TC-CONTRIB-001: readiness rows compare each input with the personal baseline.
@Test func readinessContributionsShowBaselineDeltaAndEffect_TC_CONTRIB_001() {
    let rows = MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: readinessInputs), at: insightNow)
    #expect(rows.map(\.input) == [.hrv, .restingHeartRate])
    #expect(rows[0].valueText == "55 ms")
    #expect(rows[0].baselineText == "48 ms")
    #expect(rows[0].differenceText == "+7 ms")
    #expect(rows[0].relation == .above)
    #expect(rows[0].effect == .raises)
    #expect(rows[0].effectText == "推高准备度")
    // Negative zRHR: resting heart rate above baseline lowers readiness.
    #expect(rows[1].valueText == "60 bpm")
    #expect(rows[1].baselineText == "57 bpm")
    #expect(rows[1].differenceText == "+3 bpm")
    #expect(rows[1].relation == .above)
    #expect(rows[1].effect == .lowers)
    #expect(rows[1].effectText == "拉低准备度")
    // Positive zRHR: resting heart rate below baseline raises readiness.
    let calm = MetricContributions.rows(for: .readiness, estimate: fresh(80, contributions: ["rhr": 52, "baselineRHR": 57, "zRHR": 0.8]), at: insightNow)
    #expect(calm.map(\.relation) == [.below])
    #expect(calm.map(\.effect) == [.raises])
    #expect(calm.first?.effectText == "推高准备度")
    #expect(calm.first?.differenceText == "\u{2212}5 bpm")
    for (z, effect, relation) in [(0.5, ContributionEffect.raises, BaselineRelation.above),
                                  (0.49, .nearBaseline, .near), (-0.49, .nearBaseline, .near), (-0.5, .lowers, .below)] {
        var contributions = readinessInputs
        contributions["zHRV"] = z
        let row = MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: contributions), at: insightNow)[0]
        #expect(row.effect == effect)
        #expect(row.relation == relation)
        #expect((row.effectText == nil) == (effect == .nearBaseline))
        #expect(row.relationText == ["above": "高于个人基线", "below": "低于个人基线", "near": "接近个人基线"][relation.rawValue])
    }
    // The difference uses the shown integers, so 55.4 vs 48.6 reads 55, 49, +6.
    let rounded = MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: ["hrv": 55.4, "baselineHRV": 48.6, "zHRV": 0.8]), at: insightNow)[0]
    #expect([rounded.valueText, rounded.baselineText, rounded.differenceText] == ["55 ms", "49 ms", "+6 ms"])
    let equal = fresh(50, contributions: ["rhr": 57.4, "baselineRHR": 57.2, "zRHR": 0.1])
    // Zero carries no sign (long-trends ADJ: VoiceOver reads "±" as "plus minus").
    #expect(MetricContributions.rows(for: .readiness, estimate: equal, at: insightNow).first?.differenceText == "0 bpm")
}

// TC-CONTRIB-002: stress shows heart rate values and HRV direction only.
@Test func stressContributionsShowHeartRateAndHRVDirection_TC_CONTRIB_002() {
    let rows = MetricContributions.rows(for: .stress, estimate: fresh(64, mode: "awake", contributions: stressInputs), at: insightNow)
    #expect(rows.map(\.input) == [.heartRate, .hrv])
    #expect(rows[0].valueText == "82 bpm")
    #expect(rows[0].baselineText == "71 bpm")
    #expect(rows[0].differenceText == "+11 bpm")
    #expect(rows[0].relation == .above)
    #expect(rows[0].effectText == "推高压力")
    // Positive stress zHRV means HRV below baseline, which raises stress.
    #expect(rows[1].valueText == nil)
    #expect(rows[1].baselineText == nil)
    #expect(rows[1].differenceText == nil)
    #expect(rows[1].relation == .below)
    #expect(rows[1].effectText == "推高压力")
    let calm = fresh(15, mode: "awake", contributions: ["hr": 62, "baselineHR": 70, "zHR": -1.2, "zHRV": -0.9])
    let calmRows = MetricContributions.rows(for: .stress, estimate: calm, at: insightNow)
    #expect(calmRows.map(\.effectText) == ["降低压力", "降低压力"])
    #expect(calmRows.map(\.relation) == [.below, .above])
    #expect(calmRows[0].differenceText == "\u{2212}8 bpm")
    let near = MetricContributions.rows(for: .stress, estimate: fresh(45, mode: "awake", contributions: ["hr": 71, "baselineHR": 70, "zHR": 0.3]), at: insightNow)
    #expect(near.map(\.relationText) == ["接近个人基线"])
    #expect(near.first?.effectText == nil)
    // A bucket straddling sleep is partial with sourceConflict but still used HRV.
    let straddling = fresh(64, quality: .partial, reasons: ["sourceConflict"], mode: "sleep", contributions: stressInputs)
    #expect(MetricContributions.rows(for: .stress, estimate: straddling, at: insightNow).map(\.input) == [.heartRate, .hrv])
}

// TC-CONTRIB-003: HR-only and activity stress never imply an HRV comparison.
@Test func stressHROnlyAndActivityOmitHRVRow_TC_CONTRIB_003() {
    let contributions = ["hr": 90.0, "baselineHR": 70.0, "zHR": 2.0, "zHRV": 0.0]
    for metric in [fresh(80, quality: .partial, reasons: ["hrOnly"], mode: "awake", contributions: contributions),
                   fresh(80, quality: .complete, reasons: ["hrOnly"], mode: "awake", contributions: contributions),
                   fresh(80, quality: .partial, reasons: ["hrOnly"], mode: "activity", contributions: contributions),
                   fresh(80, mode: "activity", contributions: contributions)] {
        #expect(MetricContributions.rows(for: .stress, estimate: metric, at: insightNow).map(\.input) == [.heartRate])
    }
}

// TC-CONTRIB-004: no rows for missing, stale, energy, incomplete, or non-finite inputs; no internal keys.
@Test func contributionsOmitMissingStaleAndInternalKeys_TC_CONTRIB_004() {
    let calibrating = MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: 9, mode: "night", contributions: readinessInputs)
    #expect(MetricContributions.rows(for: .readiness, estimate: calibrating, at: insightNow).isEmpty)
    let stale = MetricEstimate(72, mode: "night", contributions: readinessInputs, effectiveAt: insightNow.addingTimeInterval(-7200),
                               validUntil: insightNow.addingTimeInterval(-1))
    #expect(MetricContributions.rows(for: .readiness, estimate: stale, at: insightNow).isEmpty)
    #expect(MetricContributions.rows(for: .energy, estimate: fresh(76, mode: "energy", contributions: readinessInputs), at: insightNow).isEmpty)
    for missing in ["baselineRHR", "rhr", "zRHR"] {
        var partial = readinessInputs
        partial[missing] = nil
        #expect(MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: partial), at: insightNow).map(\.input) == [.hrv])
    }
    for (missing, expected) in [("hr", [ContributionInput.hrv]), ("baselineHR", [.hrv]), ("zHRV", [.heartRate])] {
        var partial = stressInputs
        partial[missing] = nil
        #expect(MetricContributions.rows(for: .stress, estimate: fresh(64, mode: "awake", contributions: partial), at: insightNow).map(\.input) == expected)
    }
    var nonFinite = stressInputs
    nonFinite["zHRV"] = .nan
    #expect(MetricContributions.rows(for: .stress, estimate: fresh(64, mode: "awake", contributions: nonFinite), at: insightNow).map(\.input) == [.heartRate])
    var infinite = readinessInputs
    infinite["hrv"] = .infinity
    #expect(MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: infinite), at: insightNow).map(\.input) == [.restingHeartRate])
    let rows = MetricContributions.rows(for: .readiness, estimate: fresh(72, contributions: readinessInputs), at: insightNow)
        + MetricContributions.rows(for: .stress, estimate: fresh(64, mode: "awake", contributions: stressInputs), at: insightNow)
    let texts = rows.flatMap { [$0.title, $0.valueText, $0.baselineText, $0.differenceText, $0.relationText, $0.effectText].compactMap { $0 } }
    #expect(texts.count == 21)
    for text in texts {
        for key in readinessInputs.keys.sorted() + stressInputs.keys.sorted() { #expect(!text.contains(key)) }
        #expect(!text.lowercased().contains("z"))
    }
}

// TC-CONTRIB-005: tier labels reuse the 002 display segments.
@Test(arguments: [
    (ComplicationMetric.readiness, 0, "较低"), (.readiness, 32, "较低"), (.readiness, 33, "接近个人常态"),
    (.readiness, 66, "接近个人常态"), (.readiness, 67, "较高"), (.readiness, 100, "较高"),
    (.stress, 0, "低"), (.stress, 19, "低"), (.stress, 20, "常态"), (.stress, 59, "常态"),
    (.stress, 60, "偏高"), (.stress, 79, "偏高"), (.stress, 80, "高"), (.stress, 100, "高"),
])
func tierLabelsFollowScoringBoundaries_TC_CONTRIB_005(metric: ComplicationMetric, value: Int, label: String) {
    #expect(MetricTier.label(for: metric, value: value) == label)
    #expect(MetricTier.label(for: metric, value: nil) == nil)
    #expect(MetricTier.label(for: .energy, value: value) == nil)
}

// MARK: - Daily timeline

private func hour(_ value: Double, of report: HealthReport) -> Date { report.day.addingTimeInterval(value * 3600) }
/// Order-sensitive checksums of the energy curve, comparable with a run of the code before this change.
private func checksums(_ points: [EnergyPoint]) -> (weighted: Double, times: Double) {
    var weighted = 0.0, times = 0.0
    for (index, point) in points.enumerated() {
        weighted += (point.value ?? -1) * Double(index + 1)
        times += point.at.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) * Double(index + 1)
    }
    return (weighted, times)
}

// TC-TIMELINE-001: the engine exposes the intervals its energy replay used, without changing any value.
@Test func engineExposesEnergyDriverIntervalsWithoutChangingValues_TC_TIMELINE_001() throws {
    // Expected values were printed by the same calculation on commit c515ff6, before this change
    // (work/insights-baseline-c515ff6.log, not committed).
    let plain = try DemoData.report()
    #expect(abs(plain.readiness.rawValue! - 89.20661760743698) < 1e-9)
    #expect(abs(plain.stress.rawValue! - 38.51432610525744) < 1e-9)
    #expect(abs(plain.energy.estimate.rawValue! - 76.0110310209895) < 1e-9)
    #expect(plain.energy.points.count == 841)
    #expect(abs(checksums(plain.energy.points).weighted - 23129995.642887626) < 1e-4)
    #expect(checksums(plain.energy.points).times == 11896449600)
    // mood-records keeps seven analysis days of buckets; today's still number 108.
    #expect(plain.stressTimeline.filter { $0.interval.start >= plain.day }.count == 108)

    let source = SampleSource(bundle: "wristlab.synthetic", family: "Watch", rank: 0)
    let napStart = hour(12.5, of: plain), napEnd = hour(12.5 + 0.75, of: plain)
    let records = try DemoData.records(asOf: DemoData.previewDate)
        + [HealthRecord(id: "nap-today", kind: .sleep, start: napStart, end: napEnd, stage: .core, source: source)]
    let report = try HealthEngine.evaluate(records: records, profile: HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190),
                                           asOf: DemoData.previewDate, inputRevision: 1, source: .demo)
    #expect(abs(report.energy.estimate.rawValue! - 78.4041719390294) < 1e-9)
    #expect(abs(checksums(report.energy.points).weighted - 23262765.81749231) < 1e-4)
    // Last night's 23:00–07:00 sleep is clipped to the analysis day. The 12:30 nap belongs to the next
    // sleep report window (12:00 to 12:00) yet still drives energy, so it must appear too.
    #expect(report.energy.asleepIntervals == [DateInterval(start: hour(0, of: report), end: hour(7, of: report)),
                                              DateInterval(start: napStart, end: napEnd)])
    #expect(report.energy.workoutIntervals == [DateInterval(start: hour(9, of: report), end: hour(9.5, of: report))])
}

// TC-TIMELINE-002: spans are clipped to the visible day, typed, sorted, and never empty; DST days keep their length.
@Test func dayTimelineClipsSortsAndTypesSpans_TC_TIMELINE_002() throws {
    var report = try DemoData.report()
    report.energy.asleepIntervals = [
        DateInterval(start: hour(13.5, of: report), end: hour(15, of: report)),
        DateInterval(start: hour(-2, of: report), end: hour(6, of: report)),
        DateInterval(start: hour(-4, of: report), end: hour(-3, of: report)),
        DateInterval(start: hour(10, of: report), duration: 0),
    ]
    report.energy.workoutIntervals = [DateInterval(start: hour(9, of: report), end: hour(9.5, of: report)),
                                      DateInterval(start: hour(14, of: report), end: hour(14.5, of: report))]
    let timeline = DayTimeline(report: report, at: report.asOf)
    #expect(timeline.day == DateInterval(start: hour(0, of: report), end: hour(24, of: report)))
    #expect(!timeline.isPastDay)
    #expect(timeline.spans == [
        TimelineSpan(kind: .asleep, interval: DateInterval(start: hour(0, of: report), end: hour(6, of: report))),
        TimelineSpan(kind: .workout, interval: DateInterval(start: hour(9, of: report), end: hour(9.5, of: report))),
        TimelineSpan(kind: .asleep, interval: DateInterval(start: hour(13.5, of: report), end: hour(14, of: report))),
    ])
    // 2026-11-01 in New York has 25 hours; a span from the previous evening is cut at local midnight.
    let clock = try AnalysisClock(timeZoneID: "America/New_York")
    let day = clock.day(containing: Date(timeIntervalSince1970: 1793_548_800))
    #expect(day.duration == 25 * 3600)
    report.timeZoneID = "America/New_York"
    report.day = day.start
    report.asOf = day.start.addingTimeInterval(20 * 3600)
    report.energy.asleepIntervals = [DateInterval(start: day.start.addingTimeInterval(-7200), end: day.start.addingTimeInterval(3 * 3600))]
    report.energy.workoutIntervals = []
    let dst = DayTimeline(report: report, at: report.asOf)
    #expect(dst.day == day)
    #expect(dst.spans == [TimelineSpan(kind: .asleep, interval: DateInterval(start: day.start, end: day.start.addingTimeInterval(3 * 3600)))])
    #expect(DayTimeline(report: report, at: day.end).isPastDay)
}

// TC-TIMELINE-003: a cached report written before this change decodes and simply has no spans.
@Test func legacyEnergyReportDecodesWithoutSpans_TC_TIMELINE_003() throws {
    var report = try DemoData.report()
    report.energy.asleepIntervals = [DateInterval(start: hour(0, of: report), end: hour(7, of: report))]
    report.energy.workoutIntervals = []
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
    var energy = try #require(json["energy"] as? [String: Any])
    #expect(energy["asleepIntervals"] != nil)
    energy["asleepIntervals"] = nil
    energy["workoutIntervals"] = nil
    json["energy"] = energy
    let legacy = try JSONDecoder().decode(HealthReport.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(legacy.energy.asleepIntervals == nil)
    #expect(legacy.energy.workoutIntervals == nil)
    #expect(DayTimeline(report: legacy, at: legacy.asOf).spans.isEmpty)
    #expect(legacy.energy.points == report.energy.points)
}

// TC-TIMELINE-004: only touching, valued stress buckets connect; activity buckets are marked.
@Test func stressSegmentsBreakOnGapsAndMarkActivity_TC_TIMELINE_004() throws {
    var report = try DemoData.report()
    func bucket(_ start: Double, _ value: Double?, mode: String = "awake") -> StressBucket {
        let begin = hour(start, of: report)
        return StressBucket(interval: DateInterval(start: begin, duration: 300),
                            estimate: value.map { MetricEstimate($0, mode: mode) } ?? MetricEstimate(availability: .calibrating, mode: mode))
    }
    report.stressTimeline = [bucket(8 + 15.0 / 60, 50), bucket(8, 30.4), bucket(8 + 5.0 / 60, 40.5), bucket(8 + 20.0 / 60, nil),
                             bucket(8 + 25.0 / 60, 60, mode: "activity"), bucket(-1, 20), bucket(14, 70), bucket(13.95, 70)]
    let points = DayTimeline(report: report, at: report.asOf).stress
    #expect(points.map(\.value) == [30, 41, 50, 60])
    let midpoints: [Double] = [8 + 2.5 / 60, 8 + 7.5 / 60, 8 + 17.5 / 60, 8 + 27.5 / 60]
    #expect(points.map(\.at) == midpoints.map { hour($0, of: report) })
    #expect(points[0].segment == points[1].segment)
    #expect(points[1].segment != points[2].segment)
    #expect(points[2].segment != points[3].segment)
    #expect(points.map(\.activity) == [false, false, false, true])
}

// TC-TIMELINE-005: missing energy breaks the line; a hidden current value hides the curve.
@Test func energySegmentsBreakOnMissingPoints_TC_TIMELINE_005() throws {
    var report = try DemoData.report()
    report.energy.points = [EnergyPoint(at: hour(1, of: report), value: 10), EnergyPoint(at: hour(1.1, of: report), value: 11),
                            EnergyPoint(at: hour(1.2, of: report), value: nil), EnergyPoint(at: hour(1.3, of: report), value: nil),
                            EnergyPoint(at: hour(1.4, of: report), value: 0), EnergyPoint(at: hour(15, of: report), value: 50)]
    let points = DayTimeline(report: report, at: report.asOf).energy
    #expect(points.map(\.value) == [10, 11, 0])
    #expect(points[0].segment == points[1].segment)
    #expect(points[1].segment != points[2].segment)
    // Under 80% coverage the replay still integrates, but the current value is empty and so is the curve.
    var low = report
    low.energy.estimate = MetricEstimate(reasons: ["lowCoverage"], mode: "energy", effectiveAt: report.asOf, validUntil: report.asOf.addingTimeInterval(900), coverage: 0.6)
    #expect(DayTimeline(report: low, at: report.asOf).energy.isEmpty)
    // An expired report keeps its stress history, but energy is no longer shown and the day is marked past.
    let later = report.day.addingTimeInterval(30 * 3600)
    let expired = DayTimeline(report: report, at: later)
    #expect(expired.energy.isEmpty)
    #expect(expired.isPastDay)
    #expect(!expired.stress.isEmpty)
}

// MARK: - Sleep detail and trend

private let sleepDay = DemoData.previewDate
private func at(_ hours: Double) -> Date { sleepDay.addingTimeInterval(hours * 3600) }
private func segment(_ stage: SleepStage, _ from: Double, _ to: Double) -> SleepSegment {
    SleepSegment(interval: DateInterval(start: at(from), end: at(to)), stage: stage)
}
private func episode(_ from: Double, _ to: Double, _ segments: [SleepSegment] = []) -> SleepEpisode {
    SleepEpisode(interval: DateInterval(start: at(from), end: at(to)), asleepMinutes: (to - from) * 60, completed: true, segments: segments)
}
private func sleepReport(stages: [SleepStage: Double] = [:], total: Double? = nil, efficiency: Double? = nil, latency: Double? = nil,
                         awake: Double = 0, awakenings: Int = 0, primary: SleepEpisode? = nil, naps: [SleepEpisode] = [],
                         segments: [SleepSegment]? = nil) -> SleepReport {
    SleepReport(day: sleepDay, window: DateInterval(start: at(-26), end: at(-2)), sourceGroup: "synthetic", settled: true,
                totalMinutes: total, inBedMinutes: nil, stages: stages, efficiency: efficiency, latencyMinutes: latency,
                awakeMinutes: awake, awakenings: awakenings, primary: primary, naps: naps,
                segments: segments ?? (primary?.segments ?? []) + naps.flatMap(\.segments), reasons: [])
}

// TC-SLEEPUI-001: lanes follow a fixed stage order, include awake and unknown time, never in-bed.
@Test func sleepLanesOrderStagesAndExcludeInBed_TC_SLEEPUI_001() throws {
    // Real calculator: one source, a recorded awake gap and an overlapping core/REM conflict inside the night.
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let source = SampleSource(bundle: "wristlab.synthetic", family: "Watch", rank: 0)
    let day = clock.day(containing: sleepDay).start
    func record(_ id: String, _ stage: SleepStage, _ from: Double, _ to: Double) -> HealthRecord {
        HealthRecord(id: id, kind: .sleep, start: day.addingTimeInterval(from * 3600), end: day.addingTimeInterval(to * 3600), stage: stage, source: source)
    }
    let records = [record("bed", .inBed, -1.2, 7.2), record("core1", .core, -1, 1), record("awake", .awake, 1, 1 + 10.0 / 60),
                   record("deep", .deep, 1 + 10.0 / 60, 3), record("conflict-core", .core, 3, 3 + 20.0 / 60),
                   record("conflict-rem", .rem, 3, 3 + 20.0 / 60), record("rem", .rem, 3 + 20.0 / 60, 4.5), record("core2", .core, 4.5, 7)]
    let report = SleepCalculator.report(day: day, records: records, profile: HealthProfile(timeZoneID: "UTC"), clock: clock, asOf: day.addingTimeInterval(14 * 3600))
    let breakdown = SleepBreakdown(report)
    #expect(breakdown.lanes.map(\.lane) == [.awake, .rem, .core, .core, .deep, .unknown])
    #expect(breakdown.lanes.first?.interval == DateInterval(start: day.addingTimeInterval(3600), end: day.addingTimeInterval(3600 + 600)))
    #expect(breakdown.lanes.last?.interval == DateInterval(start: day.addingTimeInterval(3 * 3600), end: day.addingTimeInterval(3 * 3600 + 1200)))
    #expect(breakdown.lanes.allSatisfy { report.primary!.interval.contains($0.interval.start) })
    // Hand-built order check including unspecified, independent of the calculator.
    let segments = [segment(.core, -14, -12), segment(.awake, -12, -11.8), segment(.deep, -11.8, -11), segment(.rem, -11, -10),
                    segment(.unspecified, -10, -9.5), segment(.unknown, -9.5, -9.3), segment(.core, -9.3, -8), segment(.inBed, -14.2, -7)]
    let manual = SleepBreakdown(sleepReport(stages: [.core: 200, .deep: 48, .rem: 60, .unspecified: 30], total: 338,
                                            primary: episode(-14, -8), segments: segments))
    #expect(manual.lanes.map(\.lane) == [.awake, .rem, .core, .core, .deep, .unspecified, .unknown])
    #expect(SleepLane.allCases.map(\.title) == ["清醒", "REM", "核心", "深睡", "未细分", "未知"])
}

// TC-SLEEPUI-002: missing stage detail stays empty instead of zero.
@Test func sleepBreakdownKeepsUnknownStagesEmpty_TC_SLEEPUI_002() throws {
    let durationOnly = SleepBreakdown(sleepReport(stages: [.unspecified: 420], total: 420, primary: episode(-14, -7, [segment(.unspecified, -14, -7)])))
    #expect(durationOnly.stageMinutes == nil)
    #expect(durationOnly.stageShares == nil)
    #expect(durationOnly.unspecifiedMinutes == 420)
    #expect(durationOnly.efficiency == nil)
    #expect(durationOnly.latencyMinutes == nil)
    #expect(durationOnly.awakeMinutes == 0)
    // REM absent while other specific stages exist reads as 0; shares divide by the stage sum, not the total.
    let staged = SleepBreakdown(sleepReport(stages: [.core: 200, .deep: 60, .unspecified: 40], total: 310, efficiency: 0.92, latency: 12,
                                            primary: episode(-14, -9, [segment(.core, -14, -9)])))
    #expect(staged.stageMinutes == [.core: 200, .deep: 60, .rem: 0])
    let shares = try #require(staged.stageShares)
    #expect(abs(shares.values.reduce(0, +) - 1) < 1e-9)
    #expect(shares[.rem] == 0)
    #expect(abs(shares[.unspecified]! - 40.0 / 300) < 1e-9)
    #expect(staged.efficiency == 0.92)
    #expect(staged.latencyMinutes == 12)
}

// TC-SLEEPUI-003: naps still show without a primary sleep; no record means no total and no awake figure.
@Test func sleepBreakdownWithoutPrimaryKeepsNaps_TC_SLEEPUI_003() {
    let later = episode(-9, -8.5, [segment(.core, -9, -8.5)]), earlier = episode(-11, -10.4, [segment(.core, -11, -10.4)])
    let napsOnly = SleepBreakdown(sleepReport(stages: [.unspecified: 66], total: 66, naps: [later, earlier]))
    #expect(napsOnly.lanes.isEmpty)
    #expect(napsOnly.naps == [earlier, later])
    #expect(napsOnly.awakeMinutes == 0)
    #expect(napsOnly.awakenings == 0)
    let empty = SleepBreakdown(sleepReport())
    #expect(empty.lanes.isEmpty)
    #expect(empty.totalMinutes == nil)
    #expect(empty.naps.isEmpty)
    #expect(empty.unspecifiedMinutes == nil)
    #expect(empty.awakeMinutes == nil)
    #expect(empty.awakenings == nil)
}

// TC-TREND-001: seven fixed calendar days ending on the report day; gaps stay nil; DST days align.
@Test func trendSeriesFixesSevenDaysAndValidMean_TC_TREND_001() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let end = clock.day(containing: sleepDay).start
    let days = (-6...0).map { clock.shiftedDay(end, by: $0) }
    var history = days.enumerated().map { index, day in
        DayOverview(day: day, readiness: 60 + index, sleepMinutes: 420 + Double(index) * 6, load: index == 5 ? nil : Double(index * 10))
    }
    history[4].readiness = nil
    history.remove(at: 2)
    // asOf in the afternoon, not an aligned midnight.
    let readiness = TrendSeries(history: history, metric: .readiness, endingAt: sleepDay, timeZoneID: "UTC")
    #expect(readiness.days.map(\.day) == days)
    #expect(readiness.days.map(\.value) == [60, 61, nil, 63, nil, 65, 66])
    #expect(readiness.validDays == 5)
    #expect(readiness.mean == (60.0 + 61 + 63 + 65 + 66) / 5)
    let sleep = TrendSeries(history: history, metric: .sleep, endingAt: sleepDay, timeZoneID: "UTC")
    #expect(sleep.days.first?.value == 7)
    #expect(sleep.days[2].value == nil)
    #expect(sleep.validDays == 6)
    let load = TrendSeries(history: history, metric: .load, endingAt: sleepDay, timeZoneID: "UTC")
    #expect(load.days.map(\.value) == [0, 10, nil, 30, 40, nil, 60])
    #expect(load.mean == 28)
    let none = TrendSeries(history: [], metric: .load, endingAt: sleepDay, timeZoneID: "UTC")
    #expect(none.days.count == 7)
    #expect(none.validDays == 0)
    #expect(none.mean == nil)
    // A duplicated day does not crash; the later row wins.
    let duplicated = TrendSeries(history: history + [DayOverview(day: end, readiness: 10, sleepMinutes: nil, load: nil)],
                                 metric: .readiness, endingAt: sleepDay, timeZoneID: "UTC")
    #expect(duplicated.days.last?.value == 10)
    // New York around the 2026-11-01 DST change: days come from the calendar, not fixed 24-hour steps.
    let york = try AnalysisClock(timeZoneID: "America/New_York")
    let yorkEnd = york.day(containing: Date(timeIntervalSince1970: 1793_800_000)).start
    let yorkDays = (-6...0).map { york.shiftedDay(yorkEnd, by: $0) }
    #expect(Set(zip(yorkDays, yorkDays.dropFirst()).map { $1.timeIntervalSince($0) }).count > 1)
    let yorkHistory = yorkDays.map { DayOverview(day: $0, readiness: 50, sleepMinutes: nil, load: nil) }
    let yorkSeries = TrendSeries(history: yorkHistory, metric: .readiness, endingAt: yorkEnd.addingTimeInterval(14 * 3600), timeZoneID: "America/New_York")
    #expect(yorkSeries.days.map(\.day) == yorkDays)
    #expect(yorkSeries.validDays == 7)
    // long-trends adds the nightly inputs as trend metrics.
    #expect(TrendMetric.allCases.map(\.title) == ["准备度", "睡眠", "负荷", "夜间HRV", "静息心率"])
}
