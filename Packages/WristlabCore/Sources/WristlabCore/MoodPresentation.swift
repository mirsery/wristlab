import Foundation

// MARK: - Self-reported mood (HealthKit State of Mind, read only)

public enum MoodKind: Int, Codable, Sendable {
    case momentaryEmotion = 1, dailyMood = 2
    public var title: String { self == .momentaryEmotion ? "即时情绪" : "每日心情" }
}

/// A user's own mood log, platform independent. Raw values mirror HealthKit's enumerations.
/// Wristlab never derives a mood; it only shows what the user recorded.
public struct MoodEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let at: Date
    public let kind: MoodKind
    public let valence: Double
    public let classification: Int
    public let labels: [Int]
    public let associations: [Int]
    public init(id: String, at: Date, kind: MoodKind, valence: Double, classification: Int, labels: [Int], associations: [Int]) {
        self.id = id; self.at = at; self.kind = kind; self.valence = valence
        self.classification = classification; self.labels = labels; self.associations = associations
    }
}

public enum MoodNames {
    private static let classifications = ["非常不愉快", "不愉快", "有点不愉快", "中性", "有点愉快", "愉快", "非常愉快"]
    private static let labels = ["惊叹", "觉得有趣", "生气", "焦虑", "羞愧", "勇敢", "平静", "满足", "失望", "气馁", "厌恶", "尴尬", "兴奋",
                                 "挫败", "感激", "内疚", "开心", "绝望", "烦躁", "嫉妒", "喜悦", "孤独", "充满热情", "安宁", "自豪", "释然",
                                 "难过", "害怕", "有压力", "惊讶", "担心", "恼火", "自信", "疲惫", "充满希望", "无所谓", "不知所措", "满意"]
    private static let associations = ["社群", "时事", "约会", "学习", "家人", "健身", "朋友", "健康", "爱好", "自我认同", "金钱", "伴侣",
                                       "自我关怀", "信仰", "任务", "旅行", "工作", "天气"]
    private static func name(_ list: [String], _ raw: Int) -> String { list.indices.contains(raw - 1) ? list[raw - 1] : "未知" }
    public static func classification(_ raw: Int) -> String { name(classifications, raw) }
    public static func label(_ raw: Int) -> String { name(labels, raw) }
    public static func association(_ raw: Int) -> String { name(associations, raw) }
}

/// Puts a mood next to the stress estimated at that time, without interpolation.
public struct MoodStressPairing: Sendable {
    /// Stress buckets expire 15 minutes after they end (002), so a mood may borrow one that recent.
    public static let window: TimeInterval = 900
    private let valued: [(interval: DateInterval, value: Int, activity: Bool)]
    private let clock: AnalysisClock?

    public init(timeline: [StressBucket], timeZoneID: String) {
        valued = timeline.compactMap { bucket in bucket.estimate.value.map { (bucket.interval, $0, bucket.estimate.mode == "activity") } }
            .sorted { $0.interval.start < $1.interval.start }
        clock = try? AnalysisClock(timeZoneID: timeZoneID)
    }

    public func stress(for entry: MoodEntry) -> Int? { match(for: entry)?.value }

    /// The paired value, and whether it came from a workout bucket (momentary emotions only).
    public func match(for entry: MoodEntry) -> (value: Int, activity: Bool)? {
        switch entry.kind {
        case .momentaryEmotion:
            // Same rule as the current stress value (002): the bucket covering the moment, else the most
            // recent valued bucket that ended at most 15 minutes earlier. Never a later bucket.
            let found = valued.last(where: { $0.interval.start <= entry.at && entry.at < $0.interval.end })
                ?? valued.last { $0.interval.end <= entry.at && entry.at.timeIntervalSince($0.interval.end) <= Self.window }
            return found.map { ($0.value, $0.activity) }
        case .dailyMood:
            guard let day = clock?.day(containing: entry.at) else { return nil }
            // Half-open day: Foundation's DateInterval.contains would also take the next midnight's bucket.
            let values = valued.filter { contains(day, $0.interval.start) }.map { Double($0.value) }
            return median(values).map { (Int($0.rounded(.toNearestOrAwayFromZero)), false) }
        }
    }
}

public struct MoodRow: Equatable, Sendable {
    public let entry: MoodEntry
    public let classificationText: String
    public let labelsText: String?
    public let associationsText: String?
    public let stress: Int?
    public let stressTier: String?
    /// The paired bucket was during a workout, where stress reflects exercise.
    public let duringActivity: Bool
    /// Daily mood of the current analysis day: the median only covers the day so far.
    public let dayInProgress: Bool
    /// Logged after the report was computed, so no stress could be paired yet.
    public let afterReport: Bool
}

/// The last seven analysis days of mood logs before now, newest first, and today's momentary marks.
public struct MoodOverview: Equatable, Sendable {
    public let rows: [MoodRow]
    public let todayMarkers: [Date]

    public init(entries: [MoodEntry], stressTimeline: [StressBucket], timeZoneID: String, now: Date, reportAsOf: Date? = nil) {
        let clock = try? AnalysisClock(timeZoneID: timeZoneID)
        let today = clock?.day(containing: now).start ?? now
        let start = clock?.shiftedDay(today, by: -6) ?? today.addingTimeInterval(-6 * 86400)
        var seen = Set<String>()
        let recent = entries.filter { $0.at >= start && $0.at <= now && seen.insert($0.id).inserted }.sorted { $0.at > $1.at }
        let pairing = MoodStressPairing(timeline: stressTimeline, timeZoneID: timeZoneID)
        rows = recent.map { entry in
            let match = pairing.match(for: entry)
            return MoodRow(entry: entry, classificationText: MoodNames.classification(entry.classification),
                           labelsText: entry.labels.isEmpty ? nil : entry.labels.map(MoodNames.label).joined(separator: "、"),
                           associationsText: entry.associations.isEmpty ? nil : entry.associations.map(MoodNames.association).joined(separator: "、"),
                           stress: match?.value, stressTier: MetricTier.label(for: .stress, value: match?.value),
                           duringActivity: match?.activity ?? false,
                           dayInProgress: entry.kind == .dailyMood && entry.at >= today,
                           afterReport: reportAsOf.map { entry.at > $0 } ?? false)
        }
        todayMarkers = recent.filter { $0.kind == .momentaryEmotion && $0.at >= today }.map(\.at).sorted()
    }
}
