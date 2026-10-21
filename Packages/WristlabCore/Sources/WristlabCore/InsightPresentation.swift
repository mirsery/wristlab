import Foundation

// MARK: - Contributions

public enum ContributionInput: String, Sendable { case hrv, restingHeartRate, heartRate }
public enum BaselineRelation: String, Sendable { case above, below, near }
public enum ContributionEffect: Sendable { case raises, lowers, nearBaseline }

/// One input of a score compared with the personal baseline. Values are display
/// strings so every screen words the comparison the same way.
public struct ContributionRow: Equatable, Sendable {
    public let input: ContributionInput
    public let relation: BaselineRelation
    public let effect: ContributionEffect
    public let title: String
    public let valueText: String?
    public let baselineText: String?
    public let differenceText: String?
    public let relationText: String
    /// nil when the input sits near its baseline; the relation already says so.
    public let effectText: String?
}

/// Explains readiness and stress through the standardized inputs the model already
/// computed. |z| < 0.5 is a display band only; it does not change any formula.
public enum MetricContributions {
    public static let nearBaselineZ = Physiology.nearBaselineZ

    public static func rows(for metric: ComplicationMetric, estimate: MetricEstimate, at now: Date) -> [ContributionRow] {
        // Stale or missing scores hide their old inputs too.
        guard MetricExplanation(estimate, at: now).displayValue != nil else { return [] }
        let c = estimate.contributions
        switch metric {
        case .energy:
            return []
        case .readiness:
            // zHRV > 0: HRV above baseline. zRHR > 0: resting HR below baseline. Both raise readiness.
            return [
                row(.hrv, "HRV（SDNN）", "ms", c["hrv"], c["baselineHRV"], c["zHRV"], positiveMeansAbove: true, metric: metric),
                row(.restingHeartRate, "静息心率", "bpm", c["rhr"], c["baselineRHR"], c["zRHR"], positiveMeansAbove: false, metric: metric),
            ].compactMap { $0 }
        case .stress:
            // zHR > 0: HR above baseline. zHRV > 0: HRV below baseline. Both raise stress.
            let heart = row(.heartRate, "心率", "bpm", c["hr"], c["baselineHR"], c["zHR"], positiveMeansAbove: true, metric: metric)
            // HR-only and activity buckets carry a placeholder zHRV of 0. Partial quality alone (e.g. a bucket
            // straddling sleep) still used HRV. The model keeps no raw stress HRV, so the row has direction only.
            let usedHRV = !estimate.reasons.contains("hrOnly") && estimate.mode != "activity"
            let hrv = usedHRV ? c["zHRV"].flatMap { $0.isFinite ? directionRow(.hrv, "HRV（SDNN）", z: $0, positiveMeansAbove: false, metric: metric) : nil } : nil
            return [heart, hrv].compactMap { $0 }
        }
    }

    private static func row(_ input: ContributionInput, _ title: String, _ unit: String, _ current: Double?, _ baseline: Double?,
                            _ z: Double?, positiveMeansAbove: Bool, metric: ComplicationMetric) -> ContributionRow? {
        guard let current, let baseline, let z, current.isFinite, baseline.isFinite, z.isFinite else { return nil }
        let base = directionRow(input, title, z: z, positiveMeansAbove: positiveMeansAbove, metric: metric)
        // The difference is taken between the shown integers so the three numbers always agree.
        let shownCurrent = Int(current.rounded(.toNearestOrAwayFromZero)), shownBaseline = Int(baseline.rounded(.toNearestOrAwayFromZero))
        let difference = shownCurrent - shownBaseline
        let sign = difference > 0 ? "+" : difference < 0 ? "−" : ""
        return ContributionRow(input: input, relation: base.relation, effect: base.effect, title: title,
                               valueText: "\(shownCurrent) \(unit)", baselineText: "\(shownBaseline) \(unit)",
                               differenceText: "\(sign)\(abs(difference)) \(unit)",
                               relationText: base.relationText, effectText: base.effectText)
    }

    private static func directionRow(_ input: ContributionInput, _ title: String, z: Double, positiveMeansAbove: Bool,
                                     metric: ComplicationMetric) -> ContributionRow {
        let effect: ContributionEffect = z >= nearBaselineZ ? .raises : z <= -nearBaselineZ ? .lowers : .nearBaseline
        let relation: BaselineRelation = switch effect {
        case .nearBaseline: .near
        case .raises: positiveMeansAbove ? .above : .below
        case .lowers: positiveMeansAbove ? .below : .above
        }
        let effectText: String? = switch (metric, effect) {
        case (_, .nearBaseline): nil
        case (.stress, .raises): "推高压力"
        case (.stress, .lowers): "降低压力"
        case (_, .raises): "推高准备度"
        case (_, .lowers): "拉低准备度"
        }
        let relationText = switch relation { case .above: "高于个人基线"; case .below: "低于个人基线"; case .near: "接近个人基线" }
        return ContributionRow(input: input, relation: relation, effect: effect, title: title, valueText: nil, baselineText: nil,
                               differenceText: nil, relationText: relationText, effectText: effectText)
    }
}

// MARK: - Tiers

/// Display segments defined in specs/002-scoring.md. Energy has no specified segments.
public enum MetricTier {
    public static func label(for metric: ComplicationMetric, value: Int?) -> String? {
        guard let value, (0...100).contains(value) else { return nil }
        switch metric {
        case .energy: return nil
        case .readiness: return value <= 32 ? "较低" : value <= 66 ? "接近个人常态" : "较高"
        case .stress: return value <= 19 ? "低" : value <= 59 ? "常态" : value <= 79 ? "偏高" : "高"
        }
    }
}

// MARK: - Daily timeline

public enum TimelineSpanKind: String, Sendable { case asleep, workout }
public struct TimelineSpan: Equatable, Sendable {
    public let kind: TimelineSpanKind
    public let interval: DateInterval
    public init(kind: TimelineSpanKind, interval: DateInterval) { self.kind = kind; self.interval = interval }
}
/// A plotted value. Points share a segment only when the line between them is observed.
public struct TimelinePoint: Equatable, Sendable {
    public let at: Date
    public let value: Double
    public let segment: Int
    public let activity: Bool
}

/// Energy and stress on the analysis day, cut wherever observation stops.
public struct DayTimeline: Equatable, Sendable {
    public let day: DateInterval
    public let energy: [TimelinePoint]
    public let stress: [TimelinePoint]
    public let spans: [TimelineSpan]
    /// True once the analysis day has ended, i.e. the chart shows an earlier day than today.
    public let isPastDay: Bool

    /// The energy curve is shown only while the current energy value is displayable: the replay keeps
    /// integrating under low coverage or after expiry, but those values must not reach the screen.
    public init(report: HealthReport, at now: Date) {
        let day = (try? AnalysisClock(timeZoneID: report.timeZoneID))?.day(containing: report.day)
            ?? DateInterval(start: report.day, duration: 86400)
        let visible = DateInterval(start: day.start, end: max(day.start, min(report.asOf, day.end)))
        self.day = day
        isPastDay = now >= day.end

        var energy: [TimelinePoint] = [], segment = 0
        let energyShown = MetricExplanation(report.energy.estimate, at: now).displayValue != nil
        for point in report.energy.points.sorted(by: { $0.at < $1.at }) where energyShown && visible.contains(point.at) {
            guard let value = point.value else { segment += 1; continue }
            energy.append(TimelinePoint(at: point.at, value: value, segment: segment, activity: false))
        }
        self.energy = energy

        var stress: [TimelinePoint] = [], previousEnd: Date?
        segment = 0
        for bucket in report.stressTimeline.sorted(by: { $0.interval.start < $1.interval.start })
        where bucket.interval.start >= visible.start && bucket.interval.end <= visible.end {
            guard let value = bucket.estimate.value else { previousEnd = nil; continue }
            if previousEnd != bucket.interval.start { segment += 1 }
            stress.append(TimelinePoint(at: bucket.interval.start.addingTimeInterval(bucket.interval.duration / 2), value: Double(value),
                                        segment: segment, activity: bucket.estimate.mode == "activity"))
            previousEnd = bucket.interval.end
        }
        self.stress = stress

        let typed = (report.energy.asleepIntervals ?? []).map { (TimelineSpanKind.asleep, $0) }
            + (report.energy.workoutIntervals ?? []).map { (TimelineSpanKind.workout, $0) }
        spans = typed.compactMap { kind, interval in intersection(interval, visible).map { TimelineSpan(kind: kind, interval: $0) } }
            .sorted { $0.interval.start < $1.interval.start }
    }
}

// MARK: - Sleep detail

/// Hypnogram rows, top to bottom. In-bed time is an overlay, not a sleep stage.
public enum SleepLane: String, CaseIterable, Sendable {
    case awake, rem, core, deep, unspecified, unknown
    public var title: String {
        switch self { case .awake: "清醒"; case .rem: "REM"; case .core: "核心"; case .deep: "深睡"; case .unspecified: "未细分"; case .unknown: "未知" }
    }
    public init?(_ stage: SleepStage) {
        switch stage {
        case .inBed: return nil
        case .awake: self = .awake
        case .rem: self = .rem
        case .core: self = .core
        case .deep: self = .deep
        case .unspecified: self = .unspecified
        case .unknown: self = .unknown
        }
    }
}
public struct SleepLaneSegment: Equatable, Sendable {
    public let lane: SleepLane
    public let interval: DateInterval
}

/// Sleep detail following specs/004-sleep.md: unknown detail stays nil, never zero.
public struct SleepBreakdown: Equatable, Sendable {
    public let lanes: [SleepLaneSegment]
    public let totalMinutes: Double?
    /// Core, deep and REM minutes; nil when the record has no specific stage at all.
    public let stageMinutes: [SleepStage: Double]?
    /// Core, deep, REM and unspecified shares summing to 1; nil without specific stages.
    public let stageShares: [SleepStage: Double]?
    public let unspecifiedMinutes: Double?
    public let efficiency: Double?
    public let latencyMinutes: Double?
    /// nil without any sleep record, so "no record" never reads as zero recorded wakefulness.
    public let awakeMinutes: Double?
    public let awakenings: Int?
    public let naps: [SleepEpisode]

    public init(_ sleep: SleepReport) {
        let order = Dictionary(uniqueKeysWithValues: SleepLane.allCases.enumerated().map { ($1, $0) })
        // Episodes keep asleep segments only; awake and unknown time inside the main sleep comes from the full timeline.
        let inPrimary = sleep.primary.map { primary in sleep.segments.compactMap { segment in
            intersection(segment.interval, primary.interval).map { SleepSegment(interval: $0, stage: segment.stage) }
        } } ?? []
        lanes = inPrimary.compactMap { segment in SleepLane(segment.stage).map { SleepLaneSegment(lane: $0, interval: segment.interval) } }
            .sorted { (order[$0.lane]!, $0.interval.start) < (order[$1.lane]!, $1.interval.start) }
        totalMinutes = sleep.totalMinutes
        let specific: [SleepStage] = [.core, .deep, .rem]
        if specific.contains(where: { sleep.stages[$0] != nil }) {
            stageMinutes = Dictionary(uniqueKeysWithValues: specific.map { ($0, sleep.stages[$0] ?? 0) })
            let shared = specific + [.unspecified]
            let sum = shared.reduce(0) { $0 + (sleep.stages[$1] ?? 0) }
            stageShares = sum > 0 ? Dictionary(uniqueKeysWithValues: shared.map { ($0, (sleep.stages[$0] ?? 0) / sum) }) : nil
        } else {
            stageMinutes = nil
            stageShares = nil
        }
        unspecifiedMinutes = sleep.stages[.unspecified]
        efficiency = sleep.efficiency
        latencyMinutes = sleep.latencyMinutes
        awakeMinutes = sleep.segments.isEmpty ? nil : sleep.awakeMinutes
        awakenings = sleep.segments.isEmpty ? nil : sleep.awakenings
        naps = sleep.naps.sorted { $0.interval.start < $1.interval.start }
    }
}

// MARK: - Trend

public enum TrendMetric: String, CaseIterable, Sendable {
    case readiness, sleep, load, nightHRV, restingHeartRate
    public var title: String {
        switch self { case .readiness: "准备度"; case .sleep: "睡眠"; case .load: "负荷"; case .nightHRV: "夜间HRV"; case .restingHeartRate: "静息心率" }
    }
    func value(in day: DayOverview?) -> Double? {
        switch self {
        case .readiness: day?.readiness.map(Double.init)
        case .sleep: day?.sleepMinutes.map { $0 / 60 }
        case .load: day?.load
        case .nightHRV: day?.nightHRV
        case .restingHeartRate: day?.restingHeartRate
        }
    }
}
public struct TrendDay: Equatable, Sendable {
    public let day: Date
    public let value: Double?
}

/// Calendar days (7 or 30) ending on the report day. A missing day stays nil so it is never drawn as zero.
public struct TrendSeries: Equatable, Sendable {
    public let metric: TrendMetric
    public let days: [TrendDay]
    public let validDays: Int
    public let mean: Double?

    public init(history: [DayOverview], metric: TrendMetric, endingAt end: Date, timeZoneID: String, length: Int = 7) {
        let byDay = Dictionary(history.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        self.metric = metric
        days = calendarDays(endingAt: end, timeZoneID: timeZoneID, count: length).map { TrendDay(day: $0, value: metric.value(in: byDay[$0])) }
        let values = days.compactMap(\.value)
        validDays = values.count
        mean = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// Analysis-day starts in the fixed analysis time zone, oldest first.
func calendarDays(endingAt end: Date, timeZoneID: String, count: Int) -> [Date] {
    let clock = try? AnalysisClock(timeZoneID: timeZoneID)
    let last = clock?.day(containing: end).start ?? end
    return (1 - max(count, 1) ... 0).map { clock?.shiftedDay(last, by: $0) ?? last.addingTimeInterval(Double($0) * 86400) }
}

// MARK: - Weekly review

public struct WeeklyRow: Equatable, Sendable {
    public let metric: TrendMetric
    public let thisWeekMean: Double?
    public let thisWeekDays: Int
    public let previousMean: Double?
    public let previousDays: Int
    /// This week minus the previous four weeks; only when both means exist.
    public let difference: Double?
    /// Digits shown for this metric: sleep hours keep one decimal, the rest are integers.
    public var fractionDigits: Int { metric == .sleep ? 1 : 0 }
    /// The difference between the two means as displayed, so the three shown numbers agree.
    /// Zero carries no sign; VoiceOver would read "±" as "plus minus".
    public var differenceText: String? {
        guard let current = thisWeekMean, let previous = previousMean else { return nil }
        let scale = pow(10, Double(fractionDigits))
        let shown = ((current * scale).rounded(.toNearestOrAwayFromZero) - (previous * scale).rounded(.toNearestOrAwayFromZero)) / scale
        let magnitude = String(format: "%.\(fractionDigits)f", abs(shown))
        return shown > 0 ? "+" + magnitude : shown < 0 ? "\u{2212}" + magnitude : magnitude
    }
}

/// The 7 days ending today against the 28 days before them. Means need 3 and 10 valid days;
/// observed load is left out because partly observed days are only lower bounds.
public struct WeeklyReview: Equatable, Sendable {
    public static let minimumThisWeekDays = 3
    public static let minimumPreviousDays = 10
    public let rows: [WeeklyRow]

    public init(history: [DayOverview], endingAt end: Date, timeZoneID: String) {
        let byDay = Dictionary(history.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        let days = calendarDays(endingAt: end, timeZoneID: timeZoneID, count: 35)
        rows = [TrendMetric.readiness, .sleep, .nightHRV, .restingHeartRate].map { metric in
            let previous = days.prefix(28).compactMap { metric.value(in: byDay[$0]) }
            let current = days.suffix(7).compactMap { metric.value(in: byDay[$0]) }
            let currentMean = current.count >= Self.minimumThisWeekDays ? current.reduce(0, +) / Double(current.count) : nil
            let previousMean = previous.count >= Self.minimumPreviousDays ? previous.reduce(0, +) / Double(previous.count) : nil
            return WeeklyRow(metric: metric, thisWeekMean: currentMean, thisWeekDays: current.count, previousMean: previousMean,
                             previousDays: previous.count, difference: currentMean.flatMap { c in previousMean.map { c - $0 } })
        }
    }
}
