import Foundation
import Testing
@testable import WristlabCore

private func mood(_ id: String, _ at: Date, _ kind: MoodKind = .momentaryEmotion, classification: Int = 5, labels: [Int] = [], associations: [Int] = []) -> MoodEntry {
    MoodEntry(id: id, at: at, kind: kind, valence: 0.2, classification: classification, labels: labels, associations: associations)
}

// TC-MOOD-001: fixed Chinese names for every known value; unknown values fall back.
@Test func moodNamesCoverAllKnownValues_TC_MOOD_001() {
    #expect((1...7).map(MoodNames.classification) == ["非常不愉快", "不愉快", "有点不愉快", "中性", "有点愉快", "愉快", "非常愉快"])
    let labels = (1...38).map(MoodNames.label)
    #expect(Set(labels).count == 38)
    #expect(!labels.contains("未知"))
    #expect(MoodNames.label(29) == "有压力")
    #expect(MoodNames.label(7) == "平静")
    let associations = (1...18).map(MoodNames.association)
    #expect(Set(associations).count == 18)
    #expect(MoodNames.association(17) == "工作")
    for name in [MoodNames.classification(0), MoodNames.classification(8), MoodNames.label(0), MoodNames.label(39), MoodNames.association(19), MoodNames.association(-1)] {
        #expect(name == "未知")
    }
    #expect(MoodKind.momentaryEmotion.title == "即时情绪")
    #expect(MoodKind.dailyMood.title == "每日心情")
}

// TC-MOOD-002: pair with the containing bucket, else one ending within 15 minutes before; daily mood uses the day's median.
@Test func moodPairsWithNearbyStressOnly_TC_MOOD_002() throws {
    let day = try AnalysisClock(timeZoneID: "UTC").day(containing: DemoData.previewDate).start
    func at(_ hours: Double) -> Date { day.addingTimeInterval(hours * 3600) }
    func bucket(_ start: Double, _ value: Double?) -> StressBucket {
        StressBucket(interval: DateInterval(start: at(start), duration: 300),
                     estimate: value.map { MetricEstimate($0, mode: "awake") } ?? MetricEstimate(availability: .calibrating, mode: "awake"))
    }
    let timeline = [bucket(10, 30), bucket(10 + 5.0 / 60, 64), bucket(11, nil), bucket(12, 81)]
    let pairing = MoodStressPairing(timeline: timeline, timeZoneID: "UTC")
    // Inside a valued bucket.
    #expect(pairing.stress(for: mood("a", at(10 + 2.0 / 60))) == 30)
    // Exactly at a bucket boundary belongs to the bucket that starts there.
    #expect(pairing.stress(for: mood("b", at(10 + 5.0 / 60))) == 64)
    // 0 and 15 minutes after the last valued bucket ended; 16 minutes is too late.
    #expect(pairing.stress(for: mood("c", at(10 + 10.0 / 60))) == 64)
    #expect(pairing.stress(for: mood("d", at(10 + 25.0 / 60))) == 64)
    #expect(pairing.stress(for: mood("e", at(10 + 26.0 / 60))) == nil)
    // Only a bucket without a value nearby.
    #expect(pairing.stress(for: mood("f", at(11 + 2.0 / 60))) == nil)
    // Daily mood: median of the day's valued buckets (30, 64, 81).
    #expect(pairing.stress(for: mood("g", at(20), .dailyMood)) == 64)
    #expect(pairing.stress(for: mood("h", at(-5), .dailyMood)) == nil)
    #expect(MoodStressPairing(timeline: [], timeZoneID: "UTC").stress(for: mood("i", at(10))) == nil)
}

// TC-MOOD-002: the report keeps seven analysis days of stress buckets; the day timeline still shows today only.
@Test func reportStressTimelineCoversSevenDays_TC_MOOD_002() throws {
    let report = try DemoData.report()
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let first = clock.shiftedDay(report.day, by: -6)
    #expect(report.stressTimeline.allSatisfy { $0.interval.start >= first && $0.interval.end <= report.asOf })
    #expect(report.stressTimeline.contains { $0.interval.start < report.day })
    #expect(report.stressTimeline.filter { $0.interval.start >= report.day }.count == 108)
    #expect(DayTimeline(report: report, at: report.asOf).stress.allSatisfy { $0.at >= report.day })
    #expect(abs(report.stress.rawValue! - 38.51432610525744) < 1e-9)
}

// TC-MOOD-003: last seven analysis days before now, newest first, deduplicated; markers are today's momentary entries.
@Test func recentMoodsUseAnalysisDaysAndDeduplicate_TC_MOOD_003() throws {
    let zone = "Asia/Shanghai"
    let clock = try AnalysisClock(timeZoneID: zone)
    let now = DemoData.previewDate
    let today = clock.day(containing: now).start
    func day(_ offset: Int, _ hours: Double) -> Date { clock.shiftedDay(today, by: offset).addingTimeInterval(hours * 3600) }
    let entries = [
        mood("old", day(-7, 23.9)), mood("first-day", day(-6, 0.1), classification: 2, labels: [4, 31], associations: [17]),
        mood("daily", day(-1, 21), .dailyMood), mood("today", day(0, 1)), mood("today", day(0, 1)),
        mood("today-daily", day(0, 2), .dailyMood), mood("future", now.addingTimeInterval(60)),
    ]
    let overview = MoodOverview(entries: entries, stressTimeline: [], timeZoneID: zone, now: now)
    #expect(overview.rows.map(\.entry.id) == ["today-daily", "today", "daily", "first-day"])
    let first = try #require(overview.rows.last)
    #expect(first.classificationText == "不愉快")
    #expect(first.labelsText == "焦虑、担心")
    #expect(first.associationsText == "工作")
    #expect(first.stress == nil)
    #expect(first.stressTier == nil)
    #expect(overview.todayMarkers == [day(0, 1)])
}

// MARK: - Review additions

// TC-MOOD-001: complete tables in SDK order.
@Test func moodNameTablesFollowSDKOrder_TC_MOOD_001() {
    #expect((1...38).map(MoodNames.label) == ["惊叹", "觉得有趣", "生气", "焦虑", "羞愧", "勇敢", "平静", "满足", "失望", "气馁", "厌恶", "尴尬", "兴奋",
                                               "挫败", "感激", "内疚", "开心", "绝望", "烦躁", "嫉妒", "喜悦", "孤独", "充满热情", "安宁", "自豪", "释然",
                                               "难过", "害怕", "有压力", "惊讶", "担心", "恼火", "自信", "疲惫", "充满希望", "无所谓", "不知所措", "满意"])
    #expect((1...18).map(MoodNames.association) == ["社群", "时事", "约会", "学习", "家人", "健身", "朋友", "健康", "爱好", "自我认同", "金钱", "伴侣",
                                                     "自我关怀", "信仰", "任务", "旅行", "工作", "天气"])
}

// TC-MOOD-002: no later buckets, borrowing rule when the covering bucket has no value, half-open local days, rounding.
@Test func moodPairingEdgesAndLocalDays_TC_MOOD_002() throws {
    let zone = "Asia/Shanghai"
    let clock = try AnalysisClock(timeZoneID: zone)
    let day = clock.day(containing: DemoData.previewDate).start
    func at(_ hours: Double) -> Date { day.addingTimeInterval(hours * 3600) }
    func bucket(_ start: Double, _ value: Double?) -> StressBucket {
        StressBucket(interval: DateInterval(start: at(start), duration: 300),
                     estimate: value.map { MetricEstimate($0, mode: "awake") } ?? MetricEstimate(availability: .calibrating, mode: "awake"))
    }
    let pairing = MoodStressPairing(timeline: [bucket(10, 30), bucket(10 + 5.0 / 60, nil), bucket(23 + 55.0 / 60, 65), bucket(24, 90)], timeZoneID: zone)
    // Never borrows a later bucket.
    #expect(pairing.stress(for: mood("before", at(10 - 2.0 / 60))) == nil)
    // Covering bucket without a value: borrow the valued one that ended within 15 minutes, as for current stress.
    #expect(pairing.stress(for: mood("gap", at(10 + 7.0 / 60))) == 30)
    // Local day 00:00–24:00 in Shanghai: the next midnight's 90 belongs to the next day; median of 30 and 65 rounds to 48.
    #expect(pairing.stress(for: mood("daily", at(8), .dailyMood)) == 48)
    #expect(pairing.stress(for: mood("next", at(24 + 1), .dailyMood)) == 90)
    let overview = MoodOverview(entries: [mood("tiered", at(23 + 57.0 / 60))], stressTimeline: [bucket(23 + 55.0 / 60, 65)], timeZoneID: zone, now: at(25))
    #expect(overview.rows.first?.stress == 65)
    #expect(overview.rows.first?.stressTier == "偏高")
}

// TC-MOOD-002: the stress timeline starts exactly six analysis days before today.
@Test func stressTimelineSpansSevenAnalysisDays_TC_MOOD_002() throws {
    let report = try DemoData.report()
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let days = Set(report.stressTimeline.map { clock.day(containing: $0.interval.start).start })
    #expect(days.count == 7)
    #expect(days.min() == clock.shiftedDay(report.day, by: -6))
}

// TC-MOOD-003: window edges and a DST week.
@Test func recentMoodWindowEdgesAndDST_TC_MOOD_003() throws {
    let zone = "America/New_York"
    let clock = try AnalysisClock(timeZoneID: zone)
    let now = Date(timeIntervalSince1970: 1_793_800_000)   // 2026-11-04, the window crosses the 2026-11-01 change
    let today = clock.day(containing: now).start
    let start = clock.shiftedDay(today, by: -6)
    let entries = [mood("edge", start), mood("before-edge", start.addingTimeInterval(-1)), mood("now", now), mood("after", now.addingTimeInterval(1))]
    let overview = MoodOverview(entries: entries, stressTimeline: [], timeZoneID: zone, now: now)
    #expect(overview.rows.map(\.entry.id) == ["now", "edge"])
    #expect(start.timeIntervalSince(today) != -6 * 86400)
}

// TC-MOOD-002 / TC-MOOD-003: workout buckets are flagged; today's daily mood and logs after the report are marked.
@Test func moodRowsFlagActivityTodayAndAfterReport_TC_MOOD_003() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let day = clock.day(containing: DemoData.previewDate).start
    func at(_ hours: Double) -> Date { day.addingTimeInterval(hours * 3600) }
    let timeline = [StressBucket(interval: DateInterval(start: at(9), duration: 300), estimate: MetricEstimate(85, mode: "activity")),
                    StressBucket(interval: DateInterval(start: at(-12), duration: 300), estimate: MetricEstimate(40, mode: "awake"))]
    let overview = MoodOverview(entries: [mood("run", at(9 + 2.0 / 60)), mood("today", at(10), .dailyMood), mood("yesterday", at(-10), .dailyMood),
                                          mood("late", at(13))],
                                stressTimeline: timeline, timeZoneID: "UTC", now: at(14), reportAsOf: at(12))
    let rows = Dictionary(uniqueKeysWithValues: overview.rows.map { ($0.entry.id, $0) })
    #expect(rows["run"]?.stress == 85)
    #expect(rows["run"]?.duringActivity == true)
    #expect(rows["today"]?.dayInProgress == true)
    #expect(rows["today"]?.duringActivity == false)
    #expect(rows["yesterday"]?.dayInProgress == false)
    #expect(rows["yesterday"]?.stress == 40)
    #expect(rows["late"]?.afterReport == true)
    #expect(rows["run"]?.afterReport == false)
}
