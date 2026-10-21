import Foundation
import Testing
@testable import WristlabCore

private func medianOf(_ values: [Double]) -> Double {
    let sorted = values.sorted(), middle = sorted.count / 2
    return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

// TC-LONG-001: 35 analysis days with nightly inputs; scores unchanged.
@Test func engineExtendsHistoryWithNightInputs_TC_LONG_001() throws {
    let report = try DemoData.report()
    #expect(report.history.count == 35)
    let clock = try AnalysisClock(timeZoneID: "UTC")
    #expect(report.history.map(\.day) == (-34...0).map { clock.shiftedDay(report.day, by: $0) })
    // Synthetic records cover the last 23 days; earlier days stay empty instead of zero.
    #expect(report.history.prefix(12).allSatisfy { $0.nightHRV == nil && $0.restingHeartRate == nil && $0.readiness == nil })
    #expect(report.history[33].nightHRV == 60)
    #expect(report.history[33].restingHeartRate == 60)
    #expect(report.history[34].nightHRV == 80)
    #expect(report.history[34].restingHeartRate == 54)
    // A day without its resting heart rate keeps the night HRV and nothing else is invented.
    let missingRHR = try DemoData.records(asOf: DemoData.previewDate).filter { !($0.kind == .restingHeartRate && $0.id.hasPrefix("-3-")) }
    let partial = try HealthEngine.evaluate(records: missingRHR, profile: HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190),
                                            asOf: DemoData.previewDate, inputRevision: 1, source: .demo)
    #expect(partial.history[31].restingHeartRate == nil)
    #expect(partial.history[31].nightHRV == 60)
    // Score values stay those of the code before this change (see TC-TIMELINE-001 for the full checksum).
    #expect(abs(report.readiness.rawValue! - 89.20661760743698) < 1e-9)
    #expect(abs(report.stress.rawValue! - 38.51432610525744) < 1e-9)
    #expect(abs(report.energy.estimate.rawValue! - 76.0110310209895) < 1e-9)
}

// TC-LONG-002: personal ranges share the readiness baseline and need 14 valid days.
@Test func personalRangesMatchReadinessBaseline_TC_LONG_002() throws {
    let history = (0..<20).map { PhysiologyPair(hrv: 40 + Double($0 * 3 % 17), heartRate: 52 + Double($0 * 5 % 9)) }
    let ranges = try #require(Physiology.personalRanges(history: history))
    let logs = history.map { log($0.hrv) }, rests = history.map(\.heartRate)
    let hc = medianOf(logs), hs = max(1.4826 * medianOf(logs.map { abs($0 - hc) }), 0.1)
    let rc = medianOf(rests), rs = max(1.4826 * medianOf(rests.map { abs($0 - rc) }), 3)
    #expect(abs(ranges.hrvLow - exp(hc - 0.5 * hs)) < 1e-9)
    #expect(abs(ranges.hrvCenter - exp(hc)) < 1e-9)
    #expect(abs(ranges.hrvHigh - exp(hc + 0.5 * hs)) < 1e-9)
    #expect(abs(ranges.restingLow - (rc - 0.5 * rs)) < 1e-9)
    #expect(abs(ranges.restingHigh - (rc + 0.5 * rs)) < 1e-9)
    #expect(ranges.days == 20)
    #expect(Physiology.personalRanges(history: Array(history.prefix(13))) == nil)
    // Invalid pairs are not counted, exactly as in readiness.
    #expect(Physiology.personalRanges(history: Array(history.prefix(13)) + [PhysiologyPair(hrv: .nan, heartRate: 60)]) == nil)
    // Constant history uses the same scale floors as readiness.
    let constant = try #require(Physiology.personalRanges(history: Array(repeating: PhysiologyPair(hrv: 60, heartRate: 60), count: 14)))
    #expect(abs(constant.hrvLow - 60 * exp(-0.05)) < 1e-9)
    #expect(constant.restingLow == 58.5)
    #expect(constant.restingHigh == 61.5)
    // The engine uses today's readiness history: 22 synthetic nights of 60 ms and 60 bpm.
    let report = try DemoData.report()
    let engine = try #require(report.personalRanges)
    #expect(engine.days == 22)
    #expect(abs(engine.hrvCenter - 60) < 1e-9)
    #expect(engine.restingLow == 58.5)
    let short = try HealthEngine.evaluate(records: DemoData.records(asOf: DemoData.previewDate).filter { $0.end >= report.day.addingTimeInterval(-12 * 86400) },
                                          profile: HealthProfile(timeZoneID: "UTC"), asOf: DemoData.previewDate, inputRevision: 1)
    #expect(short.personalRanges == nil)
}

private func overview(_ day: Date, readiness: Int? = nil, sleep: Double? = nil, load: Double? = nil, hrv: Double? = nil, rhr: Double? = nil) -> DayOverview {
    DayOverview(day: day, readiness: readiness, sleepMinutes: sleep, load: load, nightHRV: hrv, restingHeartRate: rhr)
}

// TC-LONG-003: 30-day series and nightly inputs; gaps stay nil.
@Test func trendSeriesSupportsThirtyDaysAndNightInputs_TC_LONG_003() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let end = clock.day(containing: DemoData.previewDate).start
    let days = (-34...0).map { clock.shiftedDay(end, by: $0) }
    var history = days.enumerated().map { index, day in overview(day, readiness: index, hrv: 40 + Double(index), rhr: index % 5 == 0 ? nil : 55) }
    history.remove(at: 30)
    let hrv = TrendSeries(history: history, metric: .nightHRV, endingAt: DemoData.previewDate, timeZoneID: "UTC", length: 30)
    #expect(hrv.days.map(\.day) == Array(days.suffix(30)))
    #expect(hrv.days[25].value == nil)
    #expect(hrv.days.first?.value == 45)
    #expect(hrv.validDays == 29)
    let rest = TrendSeries(history: history, metric: .restingHeartRate, endingAt: DemoData.previewDate, timeZoneID: "UTC", length: 30)
    // Days 5…34 minus the removed day 30; every fifth day has no resting heart rate.
    #expect(rest.validDays == 24)
    #expect(rest.mean == 55)
    #expect(rest.days[0].value == nil)
    #expect(rest.days[1].value == 55)
    #expect(rest.days[5].value == nil)
    // Seven days are unchanged from the previous round.
    let week = TrendSeries(history: history, metric: .readiness, endingAt: DemoData.previewDate, timeZoneID: "UTC")
    #expect(week.days.map(\.value) == [28, 29, nil, 31, 32, 33, 34])
    #expect(TrendMetric.allCases.map(\.title) == ["准备度", "睡眠", "负荷", "夜间HRV", "静息心率"])
}

// TC-LONG-004: caches written before this change decode with the new fields empty.
@Test func legacyHistoryDecodesWithoutNightInputs_TC_LONG_004() throws {
    let report = try DemoData.report()
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
    #expect(json["personalRanges"] != nil)
    json["personalRanges"] = nil
    json["history"] = try #require(json["history"] as? [[String: Any]]).map { day in
        var day = day
        day["nightHRV"] = nil
        day["restingHeartRate"] = nil
        return day
    }
    let legacy = try JSONDecoder().decode(HealthReport.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(legacy.personalRanges == nil)
    #expect(legacy.history.allSatisfy { $0.nightHRV == nil && $0.restingHeartRate == nil })
    #expect(legacy.history.map(\.readiness) == report.history.map(\.readiness))
}

// TC-WEEK-001: this week against the previous four weeks, with valid-day thresholds.
@Test func weeklyReviewComparesWithThresholds_TC_WEEK_001() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let end = clock.day(containing: DemoData.previewDate).start
    let days = (-34...0).map { clock.shiftedDay(end, by: $0) }
    // Readiness: 3 valid days this week (incl. a real 0), 10 in the previous four weeks.
    // Resting heart rate: 2 valid days this week, 9 before. Sleep: complete. HRV: none.
    let history = days.enumerated().map { index, day -> DayOverview in
        let thisWeek = index >= 28
        let readiness: Int? = thisWeek ? ([28: 0, 30: 60, 34: 90][index]) : (index % 3 == 0 && index < 30 ? 50 : nil)
        let rest: Double? = thisWeek ? ([29: 52, 33: 54][index]) : (index < 9 ? 58 : nil)
        return overview(day, readiness: readiness, sleep: 420 + (thisWeek ? 30 : 0), load: 500, rhr: rest)
    }
    #expect(history.prefix(28).filter { $0.readiness != nil }.count == 10)
    let review = WeeklyReview(history: history, endingAt: DemoData.previewDate, timeZoneID: "UTC")
    #expect(review.rows.map(\.metric) == [.readiness, .sleep, .nightHRV, .restingHeartRate])
    let readiness = review.rows[0]
    #expect(readiness.thisWeekDays == 3)
    #expect(readiness.thisWeekMean == 50)
    #expect(readiness.previousDays == 10)
    #expect(readiness.previousMean == 50)
    #expect(readiness.difference == 0)
    let sleep = review.rows[1]
    #expect(sleep.thisWeekMean == 7.5)
    #expect(sleep.previousMean == 7)
    #expect(sleep.difference == 0.5)
    #expect(review.rows[2].thisWeekMean == nil)
    #expect(review.rows[2].difference == nil)
    let rest = review.rows[3]
    #expect(rest.thisWeekDays == 2)
    #expect(rest.thisWeekMean == nil)
    #expect(rest.previousDays == 9)
    #expect(rest.previousMean == nil)
    #expect(rest.difference == nil)
}

// MARK: - Review additions (mutation-checked)

// TC-LONG-001: nightHRV uses only in-sleep HRV and needs two samples; day HRV never leaks in.
@Test func nightHRVIgnoresDaytimeAndNeedsTwoSamples_TC_LONG_001() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let source = SampleSource(bundle: "wristlab.synthetic", family: "Watch", rank: 0)
    var records = try DemoData.records(asOf: DemoData.previewDate).filter { $0.id != "-4-hrv-1.0" }
    for offset in -22...(-1) {
        for hour in [14.0, 16, 18] {
            let at = clock.shiftedDay(DemoData.previewDate, by: offset).addingTimeInterval(hour * 3600)
            records.append(HealthRecord(id: "day-\(offset)-\(hour)", kind: .hrv, start: at, end: at, value: 100, source: source))
        }
    }
    let report = try HealthEngine.evaluate(records: records, profile: HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190),
                                           asOf: DemoData.previewDate, inputRevision: 1, source: .demo)
    #expect(report.history[32].nightHRV == 60)
    #expect(report.history[30].nightHRV == nil)
    #expect(report.history[30].restingHeartRate == 60)
    let ranges = try #require(report.personalRanges)
    #expect(abs(ranges.hrvCenter - 60) < 1e-9)
    #expect(ranges.days == report.readiness.baselineDays)
    #expect(ranges.hrvCenter == report.readiness.contributions["baselineHRV"])
    #expect(ranges.restingCenter == report.readiness.contributions["baselineRHR"])
}

// TC-LONG-002: the band follows today's sleep source and exists only in night mode.
@Test func personalRangesFollowSleepSourceAndNightMode_TC_LONG_002() throws {
    let ring = SampleSource(bundle: "wristlab.synthetic.ring", family: "Ring", rank: 1)
    let ids = Set((-9...(-5)).flatMap { offset in (0..<4).map { "sleep-\(offset)-\($0)" } + ["bed-\(offset)"] })
    let mixed = try DemoData.records(asOf: DemoData.previewDate).map { record -> HealthRecord in
        var record = record
        if ids.contains(record.id) { record.source = ring }
        return record
    }
    let profile = HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190)
    let report = try HealthEngine.evaluate(records: mixed, profile: profile, asOf: DemoData.previewDate, inputRevision: 1, source: .demo)
    let ranges = try #require(report.personalRanges)
    #expect(ranges.days == 17)
    #expect(ranges.days == report.readiness.baselineDays)
    // Without last night's sleep today's readiness falls back to daytime inputs: no band, and no mixing of sources.
    let noSleep = try DemoData.records(asOf: DemoData.previewDate).filter { !$0.id.hasPrefix("sleep-0-") && $0.id != "bed-0" }
    let fallback = try HealthEngine.evaluate(records: noSleep, profile: profile, asOf: DemoData.previewDate, inputRevision: 1, source: .demo)
    #expect(fallback.readiness.mode == "dayFallback")
    #expect(fallback.personalRanges == nil)
}

// TC-LONG-002: unit band semantics match readiness exactly, including invalid pairs and calibration.
@Test func personalRangesShareReadinessValidation_TC_LONG_002() throws {
    let history = (0..<20).map { PhysiologyPair(hrv: 40 + Double($0 * 3 % 17), heartRate: 52 + Double($0 * 5 % 9)) }
    let ranges = try #require(Physiology.personalRanges(history: history))
    let invalid = [PhysiologyPair(hrv: 0, heartRate: 60), PhysiologyPair(hrv: 60, heartRate: 0), PhysiologyPair(hrv: 60, heartRate: .infinity),
                   PhysiologyPair(hrv: -1, heartRate: 60)]
    #expect(Physiology.personalRanges(history: history + invalid) == ranges)
    #expect(Physiology.personalRanges(history: Array(history.prefix(13)) + invalid) == nil)
    let rests = history.map(\.heartRate)
    #expect(abs(ranges.restingCenter - medianOf(rests)) < 1e-9)
    // The band edges are exactly |z| = 0.5 for readiness.
    let edge = Physiology.readiness(hrv: ranges.hrvHigh, rhr: ranges.restingLow, history: history)
    #expect(ranges.hrvCenter == edge.contributions["baselineHRV"])
    #expect(ranges.restingCenter == edge.contributions["baselineRHR"])
    #expect(abs(edge.contributions["zHRV"]! - Physiology.nearBaselineZ) < 1e-9)
    #expect(abs(edge.contributions["zRHR"]! - Physiology.nearBaselineZ) < 1e-9)
    let calibrating = Physiology.readiness(hrv: 60, rhr: 60, history: Array(history.prefix(13)) + invalid)
    #expect(calibrating.availability == .calibrating)
    #expect(calibrating.baselineDays == 13)
}

// TC-LONG-003 / TC-LONG-004: 30 days of readiness; a 7-day legacy history still yields 30 slots.
@Test func thirtyDayReadinessAndLegacySevenDayHistory_TC_LONG_003() throws {
    let report = try DemoData.report()
    let readiness = TrendSeries(history: report.history, metric: .readiness, endingAt: report.asOf, timeZoneID: "UTC", length: 30)
    let expected = report.history.suffix(30).compactMap(\.readiness).map(Double.init)
    #expect(readiness.days.count == 30)
    #expect(readiness.validDays == expected.count)
    #expect(readiness.mean == expected.reduce(0, +) / Double(expected.count))
    let legacy = Array(report.history.suffix(7))
    let short = TrendSeries(history: legacy, metric: .readiness, endingAt: report.asOf, timeZoneID: "UTC", length: 30)
    #expect(short.days.count == 30)
    #expect(short.days.prefix(23).allSatisfy { $0.value == nil })
    #expect(WeeklyReview(history: legacy, endingAt: report.asOf, timeZoneID: "UTC").rows[0].previousMean == nil)
}

// TC-WEEK-001: one period short means no difference; out-of-window rows ignored; DST weeks aligned; shown difference.
@Test func weeklyReviewEdgesAndShownDifference_TC_WEEK_001() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let end = clock.day(containing: DemoData.previewDate).start
    let days = (-34...0).map { clock.shiftedDay(end, by: $0) }
    let history = days.enumerated().map { index, day in
        overview(day, readiness: index >= 28 ? 70 : (index < 12 ? 61 : nil), rhr: index >= 28 ? (index % 2 == 0 ? 50 : nil) : (index < 9 ? 58 : nil))
    } + [overview(clock.shiftedDay(end, by: -35), readiness: 0, rhr: 99)]
    let review = WeeklyReview(history: history, endingAt: DemoData.previewDate, timeZoneID: "UTC")
    #expect(review.rows[0].previousDays == 12)
    #expect(review.rows[0].difference == 9)
    #expect(review.rows[0].differenceText == "+9")
    let rest = review.rows[3]
    #expect(rest.thisWeekMean == 50)
    #expect(rest.previousDays == 9)
    #expect(rest.previousMean == nil)
    #expect(rest.difference == nil)
    #expect(rest.differenceText == nil)
    #expect(review.rows[2].thisWeekDays == 0)
    #expect(review.rows[2].previousDays == 0)
    // Shown difference: round each mean first, then subtract; zero has no sign.
    func row(_ metric: TrendMetric, _ current: Double, _ previous: Double) -> WeeklyRow {
        WeeklyRow(metric: metric, thisWeekMean: current, thisWeekDays: 7, previousMean: previous, previousDays: 28, difference: current - previous)
    }
    #expect(row(.readiness, 60.4, 60.0).differenceText == "0")
    #expect(row(.readiness, 60.6, 60.4).differenceText == "+1")
    #expect(row(.restingHeartRate, 55.2, 55.5).differenceText == "\u{2212}1")
    #expect(row(.sleep, 7.04, 7.0).differenceText == "0.0")
    #expect(row(.sleep, 7.46, 7.0).differenceText == "+0.5")
    // New York weeks across the 2026-11-01 change still hold 7 and 28 analysis days.
    let york = try AnalysisClock(timeZoneID: "America/New_York")
    let yorkEnd = york.day(containing: Date(timeIntervalSince1970: 1_793_800_000 + 20 * 86400)).start
    let yorkHistory = (-34...0).map { overview(york.shiftedDay(yorkEnd, by: $0), readiness: 50) }
    let yorkRow = WeeklyReview(history: yorkHistory, endingAt: yorkEnd.addingTimeInterval(14 * 3600), timeZoneID: "America/New_York").rows[0]
    #expect(yorkRow.thisWeekDays == 7)
    #expect(yorkRow.previousDays == 28)
}
