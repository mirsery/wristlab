import Foundation

public enum AutomaticActivity: String, Codable, CaseIterable, Sendable {
    case walking, cycling, swimming, running
    public var title: String {
        switch self { case .walking: "步行"; case .cycling: "骑行"; case .swimming: "游泳"; case .running: "跑步" }
    }
    public var workoutType: String {
        switch self { case .walking: "52"; case .cycling: "13"; case .swimming: "46"; case .running: "37" }
    }
    public static func matchingTitle(_ title: String) -> Self? { allCases.first { $0.title == title } }
}
public enum MovementExperience: String, Codable, CaseIterable, Sendable {
    case starting, regular
    public var title: String { self == .starting ? "刚开始" : "规律运动" }
}
public struct AutomaticPlanConfiguration: Codable, Equatable, Sendable {
    public var experience: MovementExperience
    public var activities: [AutomaticActivity]
    public var weekdays: Set<Int>
    public var maximumMinutes: Int
    public var typicalWeeklyMinutes: Int?
    public init(experience: MovementExperience, activities: [AutomaticActivity], weekdays: Set<Int>, maximumMinutes: Int, typicalWeeklyMinutes: Int? = nil) {
        self.experience = experience; self.activities = activities; self.weekdays = weekdays
        self.maximumMinutes = maximumMinutes; self.typicalWeeklyMinutes = typicalWeeklyMinutes
    }
    public func validate() throws {
        guard !activities.isEmpty, Set(activities).count == activities.count, !weekdays.isEmpty,
              weekdays.allSatisfy({ (1...7).contains($0) }), (5...120).contains(maximumMinutes),
              typicalWeeklyMinutes.map({ (5...10080).contains($0) }) ?? true else { throw DomainError.invalidConfiguration }
    }
}
public struct GeneratedSession: Codable, Equatable, Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public var activity: AutomaticActivity
    public var minutes: Int
}
public struct GeneratedWeek: Codable, Equatable, Sendable, Identifiable {
    public var id: String {
        if let acceptanceID { return acceptanceID }
        let preferences = configuration.activities.map(\.rawValue).joined(separator: ",")
        let weekdays = configuration.weekdays.sorted().map(String.init).joined(separator: ",")
        let settings = "\(configuration.experience.rawValue):\(preferences):\(weekdays):\(configuration.maximumMinutes):\(configuration.typicalWeeklyMinutes ?? 0)"
        return "\(weekStart.timeIntervalSince1970)-\(effectiveFrom.timeIntervalSince1970)-\(timeZoneID)-\(deadline?.timeIntervalSince1970 ?? 0)-\(settings)-" + sessions.map { "\($0.day.timeIntervalSince1970):\($0.activity.rawValue):\($0.minutes)" }.joined(separator: "|")
    }
    public let weekStart: Date
    public let effectiveFrom: Date
    public let timeZoneID: String
    public let configuration: AutomaticPlanConfiguration
    public let deadline: Date?
    public var sessions: [GeneratedSession]
    public let explanation: String
    public let previousWeekID: String?
    public var ruleVersion = AutomaticWeekPlanner.version
    public var adjustment: WeekAdjustment?
    public var acceptanceID: String?
    public var acceptedAt: Date?
    public var totalMinutes: Int { sessions.reduce(0) { $0 + $1.minutes } }
    public func validate() throws {
        try configuration.validate()
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard weekStart.timeIntervalSince1970.isFinite, clock.day(containing: weekStart).start == weekStart,
              clock.calendar.component(.weekday, from: weekStart) == 2,
              effectiveFrom >= weekStart, effectiveFrom < clock.shiftedDay(weekStart, by: 7),
              sessions.count <= 7, sessions.allSatisfy({ (5...120).contains($0.minutes) }),
              Set(sessions.map(\.day)).count == sessions.count, totalMinutes <= 150,
              deadline.map({ $0.timeIntervalSince1970.isFinite }) ?? true,
              ruleVersion == AutomaticWeekPlanner.version else { throw DomainError.invalidConfiguration }
        guard acceptedAt.map({ $0.timeIntervalSince1970.isFinite }) ?? true,
              acceptanceID.map({ !$0.isEmpty }) ?? true else { throw DomainError.invalidConfiguration }
        let end = clock.shiftedDay(weekStart, by: 7)
        for session in sessions {
            guard session.day.timeIntervalSince1970.isFinite, session.day >= effectiveFrom, session.day < end,
                  clock.day(containing: session.day).start == session.day,
                  configuration.weekdays.contains(clock.calendar.component(.weekday, from: session.day)),
                  configuration.activities.contains(session.activity), (5...configuration.maximumMinutes).contains(session.minutes),
                  deadline.map({ session.day <= clock.day(containing: $0).start }) ?? true,
                  session.minutes % 5 == 0 else { throw DomainError.invalidConfiguration }
        }
    }
}
public struct AutomaticPlanningState: Codable, Equatable, Sendable {
    public var enabled = true
    public var weeks: [GeneratedWeek] = []
    public var modeChanges: [AutomaticModeRevision]?
    public init() {}
}
public struct AutomaticModeRevision: Codable, Equatable, Sendable {
    public var fromDay: String
    public var enabled: Bool
}
public enum WeekFeedback: String, Codable, CaseIterable, Sendable {
    case none, easy, suitable, hard
    public var title: String {
        switch self { case .none: "尚未反馈"; case .easy: "轻松"; case .suitable: "合适"; case .hard: "吃力" }
    }
}
public struct WeekAdjustment: Codable, Equatable, Sendable {
    public let feedback: WeekFeedback
    public let confirmedDays: Int
    public let completedDays: Int
    public let previousMinutes: Int
}
public enum AutomaticWeekPlanner {
    public static let version = "experimental-week-plan-v1"
    public static func generate(_ config: AutomaticPlanConfiguration, starting date: Date, timeZoneID: String,
                                ending deadline: Date? = nil, totalOverride: Int? = nil,
                                previousWeekID: String? = nil) throws -> GeneratedWeek {
        try config.validate()
        guard date.timeIntervalSince1970.isFinite, deadline.map({ $0.timeIntervalSince1970.isFinite }) ?? true,
              totalOverride.map({ (5...150).contains($0) }) ?? true else { throw DomainError.invalidConfiguration }
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let start = clock.day(containing: date).start
        let weekday = clock.calendar.component(.weekday, from: start)
        let weekStart = clock.shiftedDay(start, by: -((weekday + 5) % 7))
        let days = (0..<7).map { clock.shiftedDay(weekStart, by: $0) }.filter { day in
            day >= start && config.weekdays.contains(clock.calendar.component(.weekday, from: day)) &&
                (deadline.map { day <= clock.day(containing: $0).start } ?? true)
        }
        let capacity = days.count * (config.maximumMinutes / 5) * 5
        let baseline = config.typicalWeeklyMinutes ?? (config.experience == .starting ? 10 : 20) * config.weekdays.count
        let requested = totalOverride ?? max(5, (min(baseline, 150) / 5) * 5)
        var remaining = min(capacity, requested)
        var allocated = Array(repeating: 0, count: days.count)
        while remaining >= 5 {
            for index in days.indices where remaining >= 5 && allocated[index] + 5 <= config.maximumMinutes {
                allocated[index] += 5; remaining -= 5
            }
        }
        let sessions = days.indices.compactMap { index -> GeneratedSession? in
            guard allocated[index] > 0 else { return nil }
            return GeneratedSession(day: days[index], activity: config.activities[index % config.activities.count], minutes: allocated[index])
        }
        let basis = config.typicalWeeklyMinutes == nil ? "按所选经验生成初始草案，不代表观测历史" : "以你填写的典型周分钟作参考"
        return GeneratedWeek(weekStart: weekStart, effectiveFrom: start, timeZoneID: timeZoneID, configuration: config, deadline: deadline, sessions: sessions,
                             explanation: "\(basis)；受可用日期和单次上限约束。初版上限150分钟不是安全额度，不由减重差值或期限反推运动量。",
                             previousWeekID: previousWeekID)
    }
    public static func nextWeek(after previous: GeneratedWeek, feedback: WeekFeedback, confirmedDays: Int,
                                completedDays: Int, now: Date, ending deadline: Date? = nil) throws -> GeneratedWeek {
        try previous.validate()
        let clock = try AnalysisClock(timeZoneID: previous.timeZoneID)
        let nextStart = clock.shiftedDay(previous.weekStart, by: 7)
        guard nextStart > previous.weekStart, now >= nextStart, !previous.sessions.isEmpty,
              (0...previous.sessions.count).contains(confirmedDays), (0...confirmedDays).contains(completedDays) else { throw DomainError.invalidConfiguration }
        var amount = previous.totalMinutes
        if feedback == .easy && confirmedDays == previous.sessions.count && Double(completedDays) / Double(previous.sessions.count) >= 0.8 {
            amount = min(150, amount + 5)
        } else if feedback == .hard { amount = max(5, amount - 5) }
        var result = try generate(previous.configuration, starting: max(nextStart, clock.shiftedDay(now, by: 1)), timeZoneID: previous.timeZoneID,
                                  ending: deadline ?? previous.deadline, totalOverride: max(5, amount), previousWeekID: previous.id)
        result.adjustment = WeekAdjustment(feedback: feedback, confirmedDays: confirmedDays, completedDays: completedDays, previousMinutes: previous.totalMinutes)
        return result
    }
}

public struct WorkoutPauseEvent: Sendable {
    public let at: Date
    public let paused: Bool
    public init(at: Date, paused: Bool) { self.at = at; self.paused = paused }
}
public enum WorkoutActiveTime {
    public static func intervals(start: Date, end: Date, duration: Double, events: [WorkoutPauseEvent]) -> [DateInterval]? {
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              start < end, duration.isFinite, duration >= 0, duration <= end.timeIntervalSince(start) else { return nil }
        var cursor = start
        var paused = false
        var result: [DateInterval] = []
        for event in events {
            guard event.at.timeIntervalSince1970.isFinite, event.at >= cursor, event.at >= start, event.at <= end,
                  event.paused != paused else { return nil }
            if event.paused && cursor < event.at { result.append(DateInterval(start: cursor, end: event.at)) }
            cursor = event.at; paused = event.paused
        }
        if !paused && cursor < end { result.append(DateInterval(start: cursor, end: end)) }
        return cappedIntervals(result, duration: duration)
    }
    public static func cappedIntervals(_ intervals: [DateInterval], duration: Double) -> [DateInterval]? {
        guard duration.isFinite, duration >= 0 else { return nil }
        var result = union(intervals)
        let sum = result.reduce(0) { $0 + $1.duration }
        guard sum.isFinite, abs(sum - duration) <= 1 else { return nil }
        var excess = max(0, sum - duration)
        while excess > 0, let last = result.last {
            result.removeLast()
            if last.duration > excess {
                result.append(DateInterval(start: last.start, end: last.end.addingTimeInterval(-excess)))
                excess = 0
            } else { excess -= last.duration }
        }
        return result
    }
}
public struct WorkoutCompletion: Sendable {
    public let observedSeconds: Double?
    public let targetSeconds: Double
    public let sources: [String]
    public let excludedRecords: Int
    public let otherRecords: Int
    public let notes: [WorkoutRecordNote]
    public var completed: Bool { observedSeconds.map { $0 >= targetSeconds } ?? false }
    public var fraction: Double? { observedSeconds.map { min(1, $0 / targetSeconds) } }
    public init(activity: AutomaticActivity, targetMinutes: Int, day: Date, records: [HealthRecord], profile: HealthProfile, asOf: Date) throws {
        guard (1...1440).contains(targetMinutes), day.timeIntervalSince1970.isFinite, asOf.timeIntervalSince1970.isFinite else { throw DomainError.invalidConfiguration }
        let clock = try AnalysisClock(timeZoneID: profile.timeZoneID)
        let window = clock.day(containing: day)
        let selected = ActivityCalculator.deduplicatedWorkouts(RecordNormalizer.normalize(records, asOf: asOf), preferredSources: profile.preferredSources[.workout] ?? [])
            .filter { intersection($0.interval, window) != nil }
        targetSeconds = Double(targetMinutes) * 60
        var intervals: [DateInterval] = []
        var sourceNames = Set<String>()
        var excluded = 0
        var recordNotes: [WorkoutRecordNote] = []
        for record in selected where record.workoutType == activity.workoutType {
            guard let duration = record.workoutDurationSeconds, duration.isFinite, duration >= 0,
                  let active = record.workoutActiveIntervals,
                  active.allSatisfy({ $0.start >= record.start && $0.end <= record.end && $0.start < $0.end }),
                  let verified = WorkoutActiveTime.cappedIntervals(active, duration: duration) else {
                excluded += 1
                recordNotes.append(WorkoutRecordNote(record: record, reason: "活跃时段不足，未自动计入"))
                continue
            }
            let clipped = verified.compactMap { intersection($0, window) }
            intervals += clipped
            if !clipped.isEmpty { sourceNames.insert(record.source.group) }
        }
        observedSeconds = intervals.isEmpty ? nil : union(intervals).reduce(0) { $0 + $1.duration }
        sources = sourceNames.sorted(); excludedRecords = excluded
        otherRecords = selected.filter { $0.workoutType != activity.workoutType }.count
        recordNotes += selected.filter { $0.workoutType != activity.workoutType }.map { WorkoutRecordNote(record: $0, reason: "类型未匹配本项目标") }
        notes = recordNotes.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}
public struct WorkoutRecordNote: Sendable, Identifiable {
    public let id: String
    public let start: Date
    public let end: Date
    public let source: String
    public let durationSeconds: Double?
    public let activity: String
    public let reason: String
    init(record: HealthRecord, reason: String) {
        id = record.id; start = record.start; end = record.end; source = record.source.group
        durationSeconds = record.workoutDurationSeconds.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        activity = AutomaticActivity.allCases.first { $0.workoutType == record.workoutType }?.title ?? "暂不支持的运动类型"
        self.reason = reason
    }
}
