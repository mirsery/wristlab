import Foundation
import Testing
@testable import WristlabCore

private func realReport() throws -> HealthReport {
    var report = try DemoData.report()
    report.source = .healthKit
    return report
}

// TC-BRIEF-001: once per analysis day, only for today's real report with a completed main sleep.
@Test func morningBriefSendsOncePerDayAfterMainSleep_TC_BRIEF_001() throws {
    let report = try realReport()
    let now = report.day.addingTimeInterval(9 * 3600)
    let brief = try #require(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: now))
    #expect(brief.dayKey == "2026-10-20")
    #expect(MorningBrief.make(report: report, lastSentDay: "2026-10-20", hideValues: false, now: now) == nil)
    #expect(MorningBrief.make(report: report, lastSentDay: "2026-10-19", hideValues: false, now: now) != nil)
    var noSleep = report
    noSleep.sleep.primary = nil
    #expect(MorningBrief.make(report: noSleep, lastSentDay: nil, hideValues: false, now: now) == nil)
    // Yesterday's report seen the next morning is not today's brief.
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: now.addingTimeInterval(20 * 3600)) == nil)
    var demo = report
    demo.source = .demo
    #expect(MorningBrief.make(report: demo, lastSentDay: nil, hideValues: false, now: now) == nil)
    #expect(MorningBrief.make(report: nil, lastSentDay: nil, hideValues: false, now: now) == nil)
    // The day key follows the fixed analysis time zone, not the device.
    var shanghai = report
    shanghai.timeZoneID = "Asia/Shanghai"
    let clock = try AnalysisClock(timeZoneID: "Asia/Shanghai")
    let shanghaiMorning = report.day.addingTimeInterval(2 * 3600)   // 10:00 in Shanghai, 02:00 UTC
    shanghai.day = clock.day(containing: shanghaiMorning).start
    #expect(MorningBrief.make(report: shanghai, lastSentDay: nil, hideValues: false, now: shanghaiMorning)?.dayKey == clock.label(shanghaiMorning))
    // The same instant is outside the window for a UTC analysis day.
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: shanghaiMorning) == nil)
}

// TC-BRIEF-002: value with tier or the concrete reason, plus sleep; hidden mode carries neither.
@Test func morningBriefTextShowsValueOrReasonAndHides_TC_BRIEF_002() throws {
    let report = try realReport()
    let now = report.day.addingTimeInterval(9 * 3600)
    let shown = try #require(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: now))
    #expect(shown.title == "Wristlab 晨报")
    #expect(shown.body == "准备度 89 · 较高；主睡眠 8小时0分")
    var calibrating = report
    calibrating.readiness = MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: 9, mode: "night")
    let reason = try #require(MorningBrief.make(report: calibrating, lastSentDay: nil, hideValues: false, now: now))
    #expect(reason.body == "准备度：基线校准中 · 9/14天；主睡眠 8小时0分")
    var expired = report
    expired.readiness.validUntil = now.addingTimeInterval(-1)
    #expect(MorningBrief.make(report: expired, lastSentDay: nil, hideValues: false, now: now)?.body.hasPrefix("准备度：数据已过期") == true)
    let hidden = try #require(MorningBrief.make(report: report, lastSentDay: nil, hideValues: true, now: now))
    #expect(hidden.body == "主睡眠已汇总，打开Wristlab查看今天的准备度。")
    #expect(hidden.body.rangeOfCharacter(from: .decimalDigits) == nil)
    for text in [shown.body, reason.body, hidden.body] {
        for advice in ["建议", "应该", "休息", "适合", "避免", "恢复", "不妨"] { #expect(!text.contains(advice)) }
    }
}

// TC-BRIEF-001 / TC-BRIEF-002: morning window, main sleep only (naps excluded), fallback and partial marks.
@Test func morningBriefWindowMainSleepAndMarks_TC_BRIEF_002() throws {
    let report = try realReport()
    let day = report.day
    // Window: 05:00 inclusive to 14:00 exclusive in the analysis time zone.
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: day.addingTimeInterval(5 * 3600 - 1)) == nil)
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: day.addingTimeInterval(5 * 3600)) != nil)
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: day.addingTimeInterval(14 * 3600 - 1)) != nil)
    #expect(MorningBrief.make(report: report, lastSentDay: nil, hideValues: false, now: day.addingTimeInterval(14 * 3600)) == nil)
    let morning = day.addingTimeInterval(9 * 3600)
    // A nap in the same sleep window raises the total but not the main sleep.
    var napped = report
    napped.sleep.totalMinutes = (napped.sleep.totalMinutes ?? 0) + 60
    napped.sleep.naps = [SleepEpisode(interval: DateInterval(start: day.addingTimeInterval(-10 * 3600), duration: 3600), asleepMinutes: 60, completed: true, segments: [])]
    #expect(MorningBrief.make(report: napped, lastSentDay: nil, hideValues: false, now: morning)?.body.hasSuffix("主睡眠 8小时0分") == true)
    var fallback = report
    fallback.readiness.mode = "dayFallback"
    #expect(MorningBrief.make(report: fallback, lastSentDay: nil, hideValues: false, now: morning)?.body.hasPrefix("准备度 89 · 较高（日间估算）") == true)
    var partial = report
    partial.readiness.quality = .partial
    #expect(MorningBrief.make(report: partial, lastSentDay: nil, hideValues: false, now: morning)?.body.hasPrefix("准备度 89 · 较高（部分估算）") == true)
}
