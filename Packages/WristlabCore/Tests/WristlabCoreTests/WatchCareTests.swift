import Foundation
import Testing
@testable import WristlabCore

struct WatchCareTests {
    @Test func reportProjectionProvenanceAndGaps_TC_WCP_003() throws {
        var report = try DemoData.report()
        report.source = .healthKit
        let start = report.asOf.addingTimeInterval(-1200)
        report.stressTimeline = [MetricEstimate(10), MetricEstimate(), MetricEstimate(80, mode: "activity"), MetricEstimate(65, quality: .partial, reasons: ["hrOnly"])].enumerated().map { index, estimate in
            StressBucket(interval: DateInterval(start: start.addingTimeInterval(Double(index) * 300), duration: 300), estimate: estimate)
        }
        let snapshot = DisplaySnapshot(report: report, producerID: "synthetic-local", epoch: 2, sequence: 8)
        var context = CareReportContext(report: report, snapshot: snapshot)
        try context.validate()
        #expect(context.matches(snapshot))
        var changed = snapshot
        changed.sequence += 1
        #expect(!context.matches(changed))
        #expect(context.points.count == 4)
        let missing = try #require(context.points.first(where: { $0.start == start.addingTimeInterval(300) }))
        #expect(missing.level == nil && !missing.activity)
        #expect(context.points[0].level == 0)
        #expect(context.points[2].activity && context.points[2].level == nil)
        #expect(context.points[3].partial && context.points[3].level == 2)
        var envelope = try WatchDisplayEnvelope.migrate(phone: nil).enablingLocal().selecting(.local, snapshot: snapshot)
        envelope = try envelope.updatingCare(WatchCareProjection(context: context))
        #expect(envelope.careProjection?.context != nil)
        #expect(try envelope.selecting(.phone, snapshot: snapshot).careProjection?.context == nil)
        context.points = Array(repeating: CareStressPoint(start: report.asOf.addingTimeInterval(-60), end: report.asOf, level: 1, activity: false, partial: true), count: 289)
        #expect(throws: (any Error).self) { try context.validate() }
    }
    @Test func actualPresentationBoundaries_TC_WCP_001_002() throws {
        var report = try DemoData.report()
        report.source = .healthKit
        for (value, title) in [(32, "较低"), (33, "接近个人常态"), (66, "接近个人常态"), (67, "较高")] {
            report.readiness = MetricEstimate(Double(value))
            let snapshot = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
            #expect(CareMetricPresentation(snapshot: snapshot, metric: .readiness, at: report.asOf).title == title)
        }
        report.energy.estimate = MetricEstimate(0)
        report.stress = MetricEstimate(60, quality: .partial, reasons: ["hrOnly"], mode: "rest")
        report.stress.effectiveAt = report.asOf
        report.stress.validUntil = report.asOf.addingTimeInterval(900)
        let snapshot = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
        #expect(CareMetricPresentation(snapshot: snapshot, metric: .energy, at: report.asOf).energyFraction == 0)
        #expect(CareMetricPresentation(snapshot: snapshot, metric: .stress, at: report.asOf).inputNote == "仅心率估算")
        #expect(CareMetricPresentation(snapshot: snapshot, metric: .stress, at: report.asOf.addingTimeInterval(900)).isCurrent)
        var future = snapshot
        future.stress.effectiveAt = report.asOf.addingTimeInterval(1)
        #expect(!CareMetricPresentation(snapshot: future, metric: .stress, at: report.asOf).isCurrent)
    }
    @Test func pageAndActivityRoutes_TC_WCP_004_005() {
        #expect(WatchCarePage.allCases.map(\.title) == ["关怀", "活动", "状态"])
        #expect(WatchCarePage.destination(for: .activity) == .activity)
        #expect(WatchCarePage.destination(for: .stress) == .state)
        #expect(ComplicationDestination(url: ComplicationDestination.activity.url) == .activity)
    }
    @Test func activityTimelineContainsMidnight_TC_WCP_005() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-23T23:30:00Z")!
        let midnight = ISO8601DateFormatter().date(from: "2026-10-24T00:00:00Z")!
        let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
        let daily = DailyActivityReport(timeZoneID: "UTC", day: day, stepsReadAt: now)
        #expect(CareActivityTimeline.dates(daily: daily, now: now, timeZoneID: "UTC").contains(midnight))
    }
    @Test func iconBoundaries_TC_WCP_001() {
        #expect([0, 19, 20, 59, 60, 79, 80, 100].map(CareMetricPresentation.pressureLevel) == [0, 0, 1, 1, 2, 2, 3, 3])
        #expect(CareMood.allCases.map(\.title) == ["开心", "平静", "一般", "低落", "紧绷"])
        #expect(Set(CareMood.allCases.map(\.symbol)).count == 5)
    }
    @Test func pressureContextAndExpiry_TC_WCP_002() throws {
        var report = try DemoData.report()
        report.source = .healthKit
        report.stress = MetricEstimate(90, quality: .partial, reasons: ["hrOnly"], mode: "activity")
        report.stress.effectiveAt = report.asOf
        report.stress.validUntil = report.asOf.addingTimeInterval(900)
        let snapshot = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
        let active = CareMetricPresentation(snapshot: snapshot, metric: .stress, at: report.asOf)
        #expect(active.title == "运动中" && active.level == nil)
        #expect(CareMetricPresentation(snapshot: snapshot, metric: .stress, at: report.asOf.addingTimeInterval(901)).title == "待更新")
        #expect(CareMetricPresentation(snapshot: nil, metric: .stress, at: report.asOf).title == "暂无估算")
    }
    @Test func nilAndZeroSteps_TC_WDA_002() throws {
        let now = Date(timeIntervalSince1970: 1_792_483_200)
        let clock = try AnalysisClock(timeZoneID: "UTC")
        let daily = DailyActivityReport(timeZoneID: "UTC", day: clock.day(containing: now).start,
            steps: [DaySteps(day: clock.day(containing: now).start, count: 0)], stepsReadAt: now)
        try daily.validate()
        #expect(daily.currentSteps(at: now, timeZoneID: "UTC") == 0)
        #expect(DaySteps(day: now, count: -.infinity).count == nil)
        #expect(DaySteps(day: now, count: nil).count == nil)
        #expect(daily.currentSteps(at: now.addingTimeInterval(-1), timeZoneID: "UTC") == nil)
        var duplicated = daily
        duplicated.steps += daily.steps
        #expect(throws: (any Error).self) { try duplicated.validate() }
    }
    @Test func ringGoalsAndPaused_TC_WDA_003() {
        #expect(ActivityRing(value: 0, goal: nil, unit: "min").fraction == nil)
        #expect(ActivityRing(value: 50, goal: 30, unit: "min").fraction == 1)
        #expect(ActivityRing(value: 50, goal: 0, unit: "min").fraction == nil)
        let rings = ActivityRings(move: ActivityRing(value: 40, goal: 30, unit: "min"),
            exercise: ActivityRing(value: 0, goal: nil, unit: "min"), stand: ActivityRing(value: 0, goal: nil, unit: "h"), paused: true)
        #expect(!rings.hasAchievement)
    }
    @Test func dateAndStaleness_TC_WDA_004() throws {
        let clock = try AnalysisClock(timeZoneID: "America/New_York")
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        #expect(clock.day(containing: now).duration == 90000)
        let daily = DailyActivityReport(timeZoneID: "America/New_York", day: clock.day(containing: now).start,
            steps: [DaySteps(day: clock.day(containing: now).start, count: 12)], stepsReadAt: now)
        #expect(daily.currentSteps(at: now, timeZoneID: "UTC") == nil)
        #expect(daily.currentSteps(at: now.addingTimeInterval(3601), timeZoneID: daily.timeZoneID) == nil)
    }
    @Test func moodCapturedDay_TC_WCS_001() throws {
        let now = Date(timeIntervalSince1970: 1_792_483_200)
        let mood = try CareMoodRecord(mood: .low, at: now, timeZoneID: "UTC")
        #expect(mood.isCurrent(at: now, timeZoneID: "UTC"))
        #expect(!mood.isCurrent(at: now.addingTimeInterval(86400), timeZoneID: "UTC"))
        #expect(!mood.isCurrent(at: now, timeZoneID: "Asia/Shanghai"))
    }
    @Test func caringDoesNotDiagnose_TC_WCS_003() throws {
        let unknown = CareMetricPresentation(snapshot: nil, metric: .stress, at: Date(timeIntervalSince1970: 0))
        #expect(CareMessage.text(pressure: unknown, mood: .low, achieved: false).contains("记录"))
        #expect(!CareMessage.text(pressure: unknown, mood: nil, achieved: false).contains("失败"))
        var report = try DemoData.report()
        report.source = .healthKit
        report.stress = MetricEstimate(65, quality: .partial, reasons: ["hrOnly"])
        let snapshot = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
        let elevated = CareMetricPresentation(snapshot: snapshot, metric: .stress, at: report.asOf)
        #expect(CareMessage.text(pressure: elevated, mood: .low, achieved: true).contains("感受"))
        #expect(CareMessage.text(pressure: elevated, mood: nil, achieved: true).contains("如果愿意"))
        report.stress = MetricEstimate(10)
        let lowSnapshot = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 1)
        let low = CareMetricPresentation(snapshot: lowSnapshot, metric: .stress, at: report.asOf)
        #expect(CareMessage.text(pressure: low, mood: .low, achieved: false).contains("感受"))
        #expect(CareMessage.text(pressure: low, mood: nil, achieved: true).contains("设定目标"))
        #expect(CareMessage.text(pressure: low, mood: nil, achieved: false).contains("自己的节奏"))
    }
}
