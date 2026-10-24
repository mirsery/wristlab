import Foundation

public enum WatchCarePage: String, CaseIterable, Identifiable, Sendable {
    case care, activity, state
    public var id: String { rawValue }
    public var title: String { switch self { case .care: "关怀"; case .activity: "活动"; case .state: "状态" } }
    public static func destination(for destination: ComplicationDestination) -> Self {
        switch destination { case .activity: .activity; case .overview: .care; default: .state }
    }
}

public enum CareActivityTimeline {
    public static func dates(daily: DailyActivityReport?, now: Date, timeZoneID: String) -> [Date] {
        var dates = [now]
        if let clock = try? AnalysisClock(timeZoneID: timeZoneID) {
            dates.append(clock.day(containing: now).end)
        }
        dates += [daily?.stepsReadAt, daily?.ringsReadAt].compactMap { $0?.addingTimeInterval(3601) }.filter { $0 > now }
        return Array(Set(dates)).sorted()
    }
}

public enum CareMood: String, Codable, CaseIterable, Sendable, Identifiable {
    case happy, calm, neutral, low, tense
    public var id: String { rawValue }
    public var title: String {
        switch self { case .happy: "开心"; case .calm: "平静"; case .neutral: "一般"; case .low: "低落"; case .tense: "紧绷" }
    }
    public var symbol: String {
        switch self { case .happy: "sun.max"; case .calm: "leaf"; case .neutral: "circle"; case .low: "cloud.rain"; case .tense: "wind" }
    }
}

public struct CareMoodRecord: Codable, Equatable, Sendable {
    public let mood: CareMood
    public let recordedAt: Date
    public let day: Date
    public let timeZoneID: String
    public init(mood: CareMood, at now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard now.timeIntervalSince1970.isFinite else { throw DomainError.invalidConfiguration }
        self.mood = mood; recordedAt = now; day = clock.day(containing: now).start; self.timeZoneID = timeZoneID
    }
    public func isCurrent(at now: Date, timeZoneID: String) -> Bool {
        guard self.timeZoneID == timeZoneID, recordedAt <= now,
              let clock = try? AnalysisClock(timeZoneID: timeZoneID) else { return false }
        return day == clock.day(containing: now).start
    }
    public func validate() throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard recordedAt.timeIntervalSince1970.isFinite, day.timeIntervalSince1970.isFinite,
              clock.day(containing: recordedAt).start == day else { throw DomainError.invalidSnapshot }
    }
}

public struct CareMetricPresentation: Equatable, Sendable {
    public let title: String
    public let symbol: String
    public let detail: String
    public let level: Int?
    public let isCurrent: Bool
    public let energyFraction: Double?
    public let inputNote: String?
    public static func pressureLevel(_ value: Int) -> Int { value < 20 ? 0 : value < 60 ? 1 : value < 80 ? 2 : 3 }
    public init(snapshot: DisplaySnapshot?, metric: ComplicationMetric, at now: Date, demo: Bool = false) {
        var input = snapshot
        if demo, input?.source == .demo { input?.source = .healthKit }
        let display = ComplicationPresentation(snapshot: input, metric: metric, at: now)
        isCurrent = display.value != nil
        energyFraction = metric == .energy ? display.value.map { Double($0) / 100 } : nil
        inputNote = display.value != nil && metric == .stress && snapshot?.stress.reasons.contains("hrOnly") == true ? "仅心率估算" : nil
        guard let value = display.value, let snapshot else {
            level = nil
            switch display.state {
            case .stale: title = "待更新"; symbol = "clock"
            case .calibrating: title = "校准\(display.baselineDays)/14"; symbol = "hourglass"
            case .cleared: title = "已清除"; symbol = "minus.circle"
            case .failed: title = "刷新未完成"; symbol = "arrow.clockwise"
            case .unsupported: title = "暂不支持"; symbol = "questionmark.circle"
            default: title = "暂无估算"; symbol = "questionmark.circle"
            }
            switch display.state {
            case .awaitingSync: detail = "尚无可用所选报告，可主动连接手表健康或使用手机同步。"
            case .stale: detail = "报告或指标已过期，请刷新所选来源；旧记录不因此变成新记录。"
            case .cleared: detail = "所选报告已清除，重新读取需要主动连接；不删除Apple健康原始记录。"
            default: detail = display.statusText + "。" + display.detailText
            }
            return
        }
        let estimate = metric.estimate(in: snapshot)
        if metric == .stress, estimate.mode == "activity" {
            title = "运动中"; symbol = "figure.run"; level = nil
            detail = "活动情境，仅心率作部分估算，不判断心理紧张。"
        } else if metric == .stress {
            let band = Self.pressureLevel(value)
            title = ["较低", "常态", "偏高", "较高"][band]
            symbol = ["leaf", "waveform.path", "wind", "waveform.path.ecg"][band]
            level = band
            detail = estimate.reasons.contains("hrOnly") ? "仅心率估算，不代表心理状态。" : "心率与可用HRV相对个人基线的实验估算，不代表心理状态。"
        } else if metric == .readiness {
            let band = value < 33 ? 0 : value < 67 ? 1 : 2
            title = ["较低", "接近个人常态", "较高"][band]
            symbol = ["leaf", "leaf.fill", "sun.max"][band]
            level = band
            detail = "准备度是实验估算，不是运动安全保证。" + display.statusText
        } else {
            title = "身体电量估算"; symbol = "battery.0percent"; level = nil
            detail = "基于已观测休息与活动的实验估算，不是实际测得能量。" + display.statusText
        }
    }
}

public struct DaySteps: Codable, Equatable, Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public let count: Double?
    public init(day: Date, count: Double?) {
        self.day = day
        self.count = count.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}
public struct ActivityRing: Codable, Equatable, Sendable {
    public let value: Double?
    public let goal: Double?
    public let unit: String
    public init(value: Double?, goal: Double?, unit: String) {
        self.value = value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.goal = goal.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.unit = unit
    }
    public var fraction: Double? {
        guard let value, let goal else { return nil }
        return min(1, value / goal)
    }
    public var achieved: Bool { value.flatMap { value in goal.map { value >= $0 } } ?? false }
    public func validate() throws {
        guard ["kcal", "min", "h"].contains(unit), value.map({ $0.isFinite && $0 >= 0 }) ?? true,
              goal.map({ $0.isFinite && $0 > 0 }) ?? true else { throw DomainError.invalidSnapshot }
    }
}
public struct ActivityRings: Codable, Equatable, Sendable {
    public let move: ActivityRing
    public let exercise: ActivityRing
    public let stand: ActivityRing
    public let paused: Bool?
    public init(move: ActivityRing, exercise: ActivityRing, stand: ActivityRing, paused: Bool?) {
        self.move = move; self.exercise = exercise; self.stand = stand; self.paused = paused
    }
    public var hasAchievement: Bool { paused != true && [move, exercise, stand].contains(where: \.achieved) }
    public func validate() throws {
        try move.validate(); try exercise.validate(); try stand.validate()
        guard exercise.unit == "min", stand.unit == "h" else { throw DomainError.invalidSnapshot }
    }
}
public struct DailyActivityReport: Codable, Equatable, Sendable {
    public let timeZoneID: String
    public let day: Date
    public var steps: [DaySteps]
    public var stepsReadAt: Date?
    public var rings: ActivityRings?
    public var ringsReadAt: Date?
    public var stepsFailed: Bool
    public var ringsFailed: Bool
    public init(timeZoneID: String, day: Date, steps: [DaySteps] = [], stepsReadAt: Date? = nil,
                rings: ActivityRings? = nil, ringsReadAt: Date? = nil, stepsFailed: Bool = false, ringsFailed: Bool = false) {
        self.timeZoneID = timeZoneID; self.day = day; self.steps = steps; self.stepsReadAt = stepsReadAt
        self.rings = rings; self.ringsReadAt = ringsReadAt; self.stepsFailed = stepsFailed; self.ringsFailed = ringsFailed
    }
    public func isCurrent(_ date: Date?, at now: Date, timeZoneID: String) -> Bool {
        guard self.timeZoneID == timeZoneID, let date, date <= now, now.timeIntervalSince(date) <= 3600,
              let clock = try? AnalysisClock(timeZoneID: timeZoneID) else { return false }
        return day == clock.day(containing: now).start && date >= day
    }
    public func currentSteps(at now: Date, timeZoneID: String) -> Double? {
        guard isCurrent(stepsReadAt, at: now, timeZoneID: timeZoneID) else { return nil }
        return steps.first { $0.day == day }?.count
    }
    public func currentRings(at now: Date, timeZoneID: String) -> ActivityRings? {
        isCurrent(ringsReadAt, at: now, timeZoneID: timeZoneID) ? rings : nil
    }
    public func validate() throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard day.timeIntervalSince1970.isFinite, clock.day(containing: day).start == day,
              steps.count <= 7, Set(steps.map(\.day)).count == steps.count,
              [stepsReadAt, ringsReadAt].compactMap({ $0 }).allSatisfy({ $0.timeIntervalSince1970.isFinite && $0 >= day && $0 < clock.shiftedDay(day, by: 1) }),
              steps.allSatisfy({ entry in entry.day.timeIntervalSince1970.isFinite && entry.day >= clock.shiftedDay(day, by: -6) && entry.day <= day && clock.day(containing: entry.day).start == entry.day && (entry.count.map { $0.isFinite && $0 >= 0 } ?? true) }) else { throw DomainError.invalidSnapshot }
        try rings?.validate()
    }
}

public struct CareStressPoint: Codable, Equatable, Sendable, Identifiable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public let level: Int?
    public let activity: Bool
    public let partial: Bool
}
public struct CareReportContext: Codable, Equatable, Sendable {
    public let producerID: String
    public let epoch: Int
    public let sequence: Int
    public let configurationVersion: Int
    public let timeZoneID: String
    public let asOf: Date
    public var points: [CareStressPoint]
    public var graphNotice: String?
    public let heartRate: Double?
    public let baselineHeartRate: Double?
    public init(report: HealthReport, snapshot: DisplaySnapshot) {
        producerID = snapshot.producerID; epoch = snapshot.epoch; sequence = snapshot.sequence
        configurationVersion = snapshot.configurationVersion; timeZoneID = snapshot.timeZoneID; asOf = snapshot.asOf
        let start = (try? AnalysisClock(timeZoneID: report.timeZoneID))?.day(containing: report.day).start ?? report.day
        let timeline = report.stressTimeline.filter { $0.interval.start >= start && $0.interval.end <= report.asOf }
        graphNotice = timeline.count > 288 ? "当天趋势超出展示上限，未绘图。" : nil
        points = timeline.count > 288 ? [] : timeline.map { bucket in
            CareStressPoint(start: bucket.interval.start, end: bucket.interval.end,
                level: bucket.estimate.mode == "activity" ? nil : bucket.estimate.value.map(CareMetricPresentation.pressureLevel),
                activity: bucket.estimate.mode == "activity", partial: bucket.estimate.quality == .partial)
        }
        heartRate = report.stress.contributions["hr"]
        baselineHeartRate = report.stress.contributions["baselineHR"]
    }
    public func matches(_ snapshot: DisplaySnapshot?) -> Bool {
        guard let snapshot, !snapshot.clearData, snapshot.source == .healthKit else { return false }
        return producerID == snapshot.producerID && epoch == snapshot.epoch && sequence == snapshot.sequence &&
            configurationVersion == snapshot.configurationVersion && timeZoneID == snapshot.timeZoneID && asOf == snapshot.asOf
    }
    public func validate() throws {
        guard !producerID.isEmpty, epoch >= 0, sequence >= 0, TimeZone(identifier: timeZoneID) != nil,
              asOf.timeIntervalSince1970.isFinite, points.count <= 288,
              graphNotice.map({ $0.count <= 100 }) ?? true,
              [heartRate, baselineHeartRate].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 300 }),
              points.allSatisfy({ $0.start.timeIntervalSince1970.isFinite && $0.end.timeIntervalSince1970.isFinite && $0.end > $0.start && $0.end <= asOf && ($0.level.map { (0...3).contains($0) } ?? true) }) else { throw DomainError.invalidSnapshot }
    }
}
public struct WatchCareProjection: Codable, Equatable, Sendable {
    public var daily: DailyActivityReport?
    public var context: CareReportContext?
    public init(daily: DailyActivityReport? = nil, context: CareReportContext? = nil) { self.daily = daily; self.context = context }
    public func validate() throws { try daily?.validate(); try context?.validate() }
}
public struct CareState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var activityEnabled = false
    public var daily: DailyActivityReport?
    public var mood: CareMoodRecord?
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1, activityEnabled || daily == nil else { throw DomainError.invalidSnapshot }
        try daily?.validate(); try mood?.validate()
    }
}
public enum CareMessage {
    public static func text(pressure: CareMetricPresentation, mood: CareMood?, achieved: Bool) -> String {
        guard pressure.isCurrent else { return "记录还在慢慢积累，不急着下结论。" }
        if let mood {
            switch mood {
            case .low, .tense: return "你的感受被看见了，今天可以对自己温柔一点。"
            default: return "记住这一刻的感受，按自己的节奏来。"
            }
        }
        if (pressure.level ?? -1) >= 2 { return "如果愿意，给自己片刻停顿。身体估算不代表心理状态。" }
        if achieved { return "已记录的活动达到了一个设定目标，每一点照顾都值得被看见。" }
        return "按自己的节奏，今天也值得被好好对待。"
    }
}

@MainActor public protocol DailyActivityReading {
    func authorize() async throws
    func read(at now: Date, timeZoneID: String) async throws -> DailyActivityReport
    func cancel()
}
