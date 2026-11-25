import Foundation

public enum MovementGoal: String, Codable, CaseIterable, Sendable {
    case active, fitness, weight
    public var title: String {
        switch self { case .active: "保持活跃"; case .fitness: "提升体能"; case .weight: "辅助减重" }
    }
}
public enum PlanStatus: String, Codable, CaseIterable, Sendable { case active, paused, archived }
public enum MovementStatus: String, Codable, Sendable { case planned, completed, rested }
public struct MovementPlan: Codable, Equatable, Sendable {
    public var goal: MovementGoal
    public var weekdays: Set<Int>
    public var activity: String
    public var minutes: Int
    public var lightActivity: String
    public var lightMinutes: Int
    public var status: PlanStatus = .active
    public init(goal: MovementGoal, weekdays: Set<Int>, activity: String, minutes: Int, lightActivity: String = "", lightMinutes: Int = 10) {
        self.goal = goal; self.weekdays = weekdays; self.activity = activity; self.minutes = minutes
        self.lightActivity = lightActivity; self.lightMinutes = lightMinutes
    }
}
public struct MovementEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String { day }
    public var day: String
    public var activity: String
    public var minutes: Int
    public var status: MovementStatus
}
public struct MovementPlanRevision: Codable, Equatable, Sendable {
    public var fromDay: String
    public var plan: MovementPlan
}
public enum WeightUnit: String, CaseIterable, Sendable {
    case kilograms, pounds
    public var title: String { self == .kilograms ? "kg" : "lb" }
    public func kilograms(_ value: Double) -> Double { self == .kilograms ? value : value * 0.45359237 }
    public func display(_ kilograms: Double) -> Double { self == .kilograms ? kilograms : kilograms / 0.45359237 }
}
public struct WeightEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kilograms: Double
    public var at: Date
    public var recordedAt: Date
    public var source: String { "manual" }
    public init(id: String = UUID().uuidString, kilograms: Double, at: Date, recordedAt: Date) {
        self.id = id; self.kilograms = kilograms; self.at = at; self.recordedAt = recordedAt
    }
}
public struct WeightGoal: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var startKilograms: Double
    public var targetKilograms: Double
    public var start: Date
    public var deadline: Date
    public var status: PlanStatus
    public init(id: String = UUID().uuidString, startKilograms: Double, targetKilograms: Double, start: Date, deadline: Date, status: PlanStatus = .active) {
        self.id = id; self.startKilograms = startKilograms; self.targetKilograms = targetKilograms
        self.start = start; self.deadline = deadline; self.status = status
    }
}
public struct PlanningState: Codable, Equatable, Sendable {
    public var plan: MovementPlan?
    public var automatic: AutomaticPlanningState?
    public var planHistory: [MovementPlanRevision] = []
    public var entries: [MovementEntry] = []
    public var weights: [WeightEntry] = []
    public var weightGoals: [WeightGoal] = []
    public var goal: WeightGoal? { weightGoals.last }
    public init() {}
    private func validatePlan(_ value: MovementPlan) throws {
        guard !value.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.weekdays.isEmpty, value.weekdays.allSatisfy({ (1...7).contains($0) }),
              (1...1440).contains(value.minutes), value.lightActivity.isEmpty || (1...value.minutes).contains(value.lightMinutes),
              value.activity.count <= 100, value.lightActivity.count <= 100 else { throw DomainError.invalidConfiguration }
    }
    private func validDay(_ label: String) -> Bool {
        guard let date = ISO8601DateFormatter().date(from: label + "T00:00:00Z"), let clock = try? AnalysisClock(timeZoneID: "UTC") else { return false }
        return clock.label(date) == label
    }
    public mutating func configurePlan(_ value: MovementPlan, at now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let today = clock.label(now)
        entries.removeAll { $0.day >= today && $0.status == .planned }
        plan = value
        automatic?.enabled = false
        if automatic != nil {
            if automatic?.modeChanges == nil { automatic?.modeChanges = [] }
            automatic?.modeChanges?.append(AutomaticModeRevision(fromDay: today, enabled: false))
        }
        planHistory.append(MovementPlanRevision(fromDay: today, plan: value))
    }
    public mutating func acceptAutomatic(_ week: GeneratedWeek, at now: Date, timeZoneID: String) throws {
        try week.validate()
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard week.timeZoneID == timeZoneID, !week.sessions.isEmpty,
              week.effectiveFrom > clock.day(containing: now).start,
              week.sessions.allSatisfy({ $0.day > clock.day(containing: now).start }) else { throw DomainError.invalidConfiguration }
        if automatic == nil { automatic = AutomaticPlanningState() }
        automatic?.enabled = true
        if automatic?.modeChanges == nil { automatic?.modeChanges = [] }
        automatic?.modeChanges?.append(AutomaticModeRevision(fromDay: clock.label(week.effectiveFrom), enabled: true))
        var accepted = week
        accepted.acceptanceID = UUID().uuidString
        accepted.acceptedAt = now
        automatic?.weeks.append(accepted)
        entries.removeAll { entry in
            entry.status == .planned && entry.day >= clock.label(week.effectiveFrom) &&
                entry.day < clock.label(clock.shiftedDay(week.weekStart, by: 7))
        }
    }
    public mutating func switchToManual(at now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        automatic?.enabled = false
        if automatic != nil {
            if automatic?.modeChanges == nil { automatic?.modeChanges = [] }
            automatic?.modeChanges?.append(AutomaticModeRevision(fromDay: clock.label(now), enabled: false))
        }
    }
    public func usesAutomatic(at date: Date, timeZoneID: String) throws -> Bool {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard let automatic else { return false }
        if let changes = automatic.modeChanges {
            return changes.last(where: { $0.fromDay <= clock.label(date) })?.enabled ?? false
        }
        return automatic.enabled && automatic.weeks.contains { $0.effectiveFrom <= date }
    }
    public func scheduledEntry(at date: Date, timeZoneID: String) throws -> MovementEntry? {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let day = clock.label(date)
        if let entry = entries.first(where: { $0.day == day }) { return entry }
        if let automatic, try usesAutomatic(at: date, timeZoneID: timeZoneID) {
            guard let week = automatic.weeks.last(where: { week in
                guard let weekClock = try? AnalysisClock(timeZoneID: week.timeZoneID), week.timeZoneID == timeZoneID else { return false }
                return date >= week.effectiveFrom && date < weekClock.shiftedDay(week.weekStart, by: 7)
            }), let session = week.sessions.first(where: { clock.label($0.day) == day }) else { return nil }
            return MovementEntry(day: day, activity: session.activity.title, minutes: session.minutes, status: .planned)
        }
        let template = planHistory.isEmpty ? plan : planHistory.last(where: { $0.fromDay <= day })?.plan
        guard let template, template.status == .active,
              template.weekdays.contains(clock.calendar.component(.weekday, from: date)) else { return nil }
        return MovementEntry(day: day, activity: template.activity, minutes: template.minutes, status: .planned)
    }
    public mutating func replaceToday(activity: String, minutes: Int, at now: Date, timeZoneID: String) throws {
        guard let entry = try scheduledEntry(at: now, timeZoneID: timeZoneID), entry.status == .planned,
              (try usesAutomatic(at: now, timeZoneID: timeZoneID)) || plan?.status == .active,
              !activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (1...1440).contains(minutes) else { throw DomainError.invalidConfiguration }
        entries.removeAll { $0.day == entry.day }
        entries.append(MovementEntry(day: entry.day, activity: activity, minutes: minutes, status: .planned))
    }
    public func validate(asOf now: Date) throws {
        guard now.timeIntervalSince1970.isFinite else { throw DomainError.invalidConfiguration }
        if let plan { try validatePlan(plan) }
        for week in automatic?.weeks ?? [] { try week.validate() }
        guard automatic?.modeChanges?.allSatisfy({ validDay($0.fromDay) }) ?? true else { throw DomainError.invalidConfiguration }
        for revision in planHistory {
            guard validDay(revision.fromDay) else { throw DomainError.invalidConfiguration }
            try validatePlan(revision.plan)
        }
        guard Set(weights.map(\.id)).count == weights.count, Set(entries.map(\.day)).count == entries.count,
              Set(weightGoals.map(\.id)).count == weightGoals.count else { throw DomainError.invalidConfiguration }
        for entry in weights {
            guard entry.kilograms.isFinite, entry.kilograms > 0, entry.at.timeIntervalSince1970.isFinite,
                  entry.recordedAt.timeIntervalSince1970.isFinite, entry.at <= now, entry.recordedAt <= now else { throw DomainError.invalidConfiguration }
        }
        for goal in weightGoals {
            guard goal.startKilograms.isFinite, goal.targetKilograms.isFinite, goal.targetKilograms > 0,
                  goal.startKilograms > goal.targetKilograms, goal.start.timeIntervalSince1970.isFinite,
                  goal.deadline.timeIntervalSince1970.isFinite, goal.start <= now, goal.deadline > goal.start else { throw DomainError.invalidConfiguration }
        }
        for entry in entries {
            guard validDay(entry.day), (1...1440).contains(entry.minutes), !entry.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  entry.activity.count <= 100 else { throw DomainError.invalidConfiguration }
        }
    }
    public mutating func mark(_ status: MovementStatus, at now: Date, timeZoneID: String, useLight: Bool = false) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        guard (try usesAutomatic(at: now, timeZoneID: timeZoneID)) || plan?.status == .active else { throw DomainError.invalidConfiguration }
        let day = clock.label(now)
        if let index = entries.firstIndex(where: { $0.day == day }) {
            guard !useLight || entries[index].status == .planned else { throw DomainError.invalidConfiguration }
            if entries[index].status == status && !useLight { return }
            if useLight {
                guard let plan, plan.status == .active, !plan.lightActivity.isEmpty else { throw DomainError.invalidConfiguration }
                entries[index].activity = plan.lightActivity; entries[index].minutes = plan.lightMinutes
            }
            entries[index].status = status
            return
        }
        guard let scheduled = try scheduledEntry(at: now, timeZoneID: timeZoneID),
              !useLight || plan.map({ !$0.lightActivity.isEmpty && $0.status == .active }) == true else { throw DomainError.invalidConfiguration }
        entries.append(MovementEntry(day: day, activity: useLight ? (plan?.lightActivity ?? scheduled.activity) : scheduled.activity,
                                     minutes: useLight ? (plan?.lightMinutes ?? scheduled.minutes) : scheduled.minutes, status: status))
    }
    public static func demo(at now: Date, timeZoneID: String) -> PlanningState {
        var result = PlanningState()
        result.plan = MovementPlan(goal: .active, weekdays: Set(1...7), activity: "步行", minutes: 30, lightActivity: "舒缓活动", lightMinutes: 10)
        guard let clock = try? AnalysisClock(timeZoneID: timeZoneID) else { return result }
        result.weightGoals = [WeightGoal(startKilograms: 80, targetKilograms: 76, start: clock.shiftedDay(now, by: -21), deadline: clock.shiftedDay(now, by: 90))]
        result.weights = (0..<21).map { offset in
            WeightEntry(id: "synthetic-weight-\(offset)", kilograms: 79 + Double(offset) * 0.03,
                        at: clock.shiftedDay(now, by: -offset), recordedAt: now)
        }
        return result
    }
}
public struct PlanSuggestion: Sendable {
    public static let version = "activity-plan-v1"
    public let activity: String?
    public let minutes: Int?
    public let message: String
    public private(set) var canChooseLight = false
    public init(state: PlanningState, report: HealthReport?, now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let entry = try state.scheduledEntry(at: now, timeZoneID: timeZoneID)
        activity = entry?.activity
        minutes = entry?.minutes
        guard try !state.usesAutomatic(at: now, timeZoneID: timeZoneID) else {
            if let entry, entry.status == .completed { message = "已手动标记完成，实际运动分钟单独统计。" }
            else if let entry, entry.status == .rested { message = "今天选择休息，无需补课。" }
            else if entry != nil, let report, report.asOf <= now,
                    clock.day(containing: report.day).start == clock.day(containing: now).start,
                    report.readiness.availability == .available, report.readiness.effectiveAt != nil,
                    report.readiness.validUntil != nil, !report.readiness.isStale(at: now),
                    let value = report.readiness.value, value <= 32 {
                self.canChooseLight = state.plan.map { $0.status == .active && !$0.lightActivity.isEmpty } == true
                message = "准备度较低，可选择休息" + (self.canChooseLight ? "或预设轻量安排；调整前保留原目标。" : "；原目标不自动降低。")
            } else { message = entry == nil ? "今天未采纳自动安排或原定休息；可预览并采纳下一周。" : "按你已采纳的周计划执行，实际记录单独统计；可自主选择休息。" }
            return
        }
        guard let plan = state.plan else { message = "设置每周活动安排，建立自己的节奏。"; return }
        guard plan.status == .active else { message = "计划已暂停；历史记录保留。"; return }
        if let entry, entry.status != .planned {
            message = entry.status == .completed ? "已手动标记完成，不再追加安排。" : "今天选择休息，无需补课。"
            return
        }
        guard entry != nil || plan.weekdays.contains(clock.calendar.component(.weekday, from: now)) else {
            message = "今天原定休息或自由安排。"; return
        }
        guard let report else { message = "显示原定安排：暂无健康报告，不作个性化调整。"; return }
        guard clock.day(containing: report.day).start == clock.day(containing: now).start, report.asOf <= now else {
            message = "显示原定安排：报告不是当前分析日的有效报告，不作个性化调整。"; return
        }
        guard report.readiness.availability == .available, !report.readiness.isStale(at: now), let value = report.readiness.value else {
            message = "显示原定安排：" + MetricExplanation(report.readiness, at: now).detail + " 不作个性化调整。"; return
        }
        guard report.readiness.effectiveAt != nil, report.readiness.validUntil != nil else {
            message = "显示原定安排：缺少准备度的数据时间或有效期，不作个性化调整。"; return
        }
        if value <= 32 {
            self.canChooseLight = !plan.lightActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            message = "准备度较低，可选择休息" + (self.canChooseLight ? "或预设轻量安排。" : "。")
        } else { message = "保留原定安排；状态估算不代表运动安全保证，不自动加量。" }
    }
}
public struct WeightDay: Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public let kilograms: Double
    public var segment: Int = 0
}
public struct WeightProgress: Sendable {
    public let days: [WeightDay]
    public let currentWeekDays: Int
    public let previousWeekDays: Int
    public let currentWeekMean: Double?
    public let previousWeekMean: Double?
    public var difference: Double? {
        guard let currentWeekMean, let previousWeekMean else { return nil }
        return currentWeekMean - previousWeekMean
    }
    public init(records: [WeightEntry], now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let valid = records.filter { $0.at <= now && $0.kilograms.isFinite && $0.kilograms > 0 }
        let grouped = Dictionary(grouping: valid, by: { clock.day(containing: $0.at).start })
        let sorted = grouped.compactMap { day, entries in
            entries.max { first, second in
                if first.at != second.at { return first.at < second.at }
                if first.recordedAt != second.recordedAt { return first.recordedAt < second.recordedAt }
                return first.id < second.id
            }.map { WeightDay(day: day, kilograms: $0.kilograms) }
        }.sorted { $0.day < $1.day }
        var segment = 0
        days = sorted.enumerated().map { index, value in
            if index > 0 && clock.shiftedDay(sorted[index - 1].day, by: 1) != value.day { segment += 1 }
            var day = value; day.segment = segment
            return day
        }
        let weekday = clock.calendar.component(.weekday, from: now)
        let start = clock.shiftedDay(clock.day(containing: now).start, by: -((weekday + 5) % 7))
        let previous = clock.shiftedDay(start, by: -7)
        let currentValues = days.filter { $0.day >= start }.map(\.kilograms)
        let previousValues = days.filter { $0.day >= previous && $0.day < start }.map(\.kilograms)
        currentWeekDays = currentValues.count; previousWeekDays = previousValues.count
        currentWeekMean = currentValues.count >= 3 ? currentValues.reduce(0, +) / Double(currentValues.count) : nil
        previousWeekMean = previousValues.count >= 3 ? previousValues.reduce(0, +) / Double(previousValues.count) : nil
    }
}
