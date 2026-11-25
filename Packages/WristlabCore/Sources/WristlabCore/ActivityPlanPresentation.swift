import Foundation

public struct ActivityPlanDay: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let entry: MovementEntry?
    public let isToday: Bool
}

public struct ActivityPlanPresentation: Sendable {
    public enum Mode: Sendable {
        case unconfigured, manual, automatic, paused
        public var title: String {
            switch self {
            case .unconfigured: "今天没有生效计划"
            case .manual: "今天使用手动安排"
            case .automatic: "今天使用自动周计划"
            case .paused: "手动计划已暂停"
            }
        }
    }
    public let mode: Mode
    public let hasPlan: Bool
    public let pendingAutomaticStart: Date?
    public let days: [ActivityPlanDay]

    public init(state: PlanningState, now: Date, timeZoneID: String) throws {
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let today = clock.day(containing: now).start
        let template = state.planHistory.isEmpty ? state.plan : state.planHistory.last(where: { $0.fromDay <= clock.label(now) })?.plan
        if try state.usesAutomatic(at: now, timeZoneID: timeZoneID) { mode = .automatic }
        else if template?.status == .active { mode = .manual }
        else if template != nil { mode = .paused }
        else { mode = .unconfigured }
        hasPlan = state.plan != nil || !state.planHistory.isEmpty || !state.entries.isEmpty || !(state.automatic?.weeks.isEmpty ?? true)
        pendingAutomaticStart = try (state.automatic?.weeks ?? []).filter { week in
            guard week.timeZoneID == timeZoneID, week.effectiveFrom > today else { return false }
            return try state.usesAutomatic(at: week.effectiveFrom, timeZoneID: timeZoneID)
        }.map(\.effectiveFrom).min()
        let weekday = clock.calendar.component(.weekday, from: today)
        let monday = clock.shiftedDay(today, by: -((weekday + 5) % 7))
        days = try (0..<7).map { offset in
            let day = clock.shiftedDay(monday, by: offset)
            return ActivityPlanDay(date: day, entry: try state.scheduledEntry(at: day, timeZoneID: timeZoneID), isToday: day == today)
        }
    }
}
