import Foundation
import Testing
@testable import WristlabCore

@Test func activityPresentationFutureOnlyDoesNotInventCurrentMode_TC_ACTUI_001() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    let start = date("2026-10-23T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    try state.acceptAutomatic(AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC"), at: now, timeZoneID: "UTC")
    let view = try ActivityPlanPresentation(state: state, now: now, timeZoneID: "UTC")
    #expect(view.hasPlan)
    #expect(view.mode == .unconfigured)
    #expect(view.pendingAutomaticStart == start)
    #expect(view.days.first { $0.isToday }?.entry == nil)
}

@Test func activityPresentationCurrentAutomaticKeepsCompletedSnapshot_TC_ACTUI_003() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    let week = try AutomaticWeekPlanner.generate(config, starting: date("2026-10-22T00:00:00Z"), timeZoneID: "UTC")
    try state.acceptAutomatic(week, at: now.addingTimeInterval(-86400), timeZoneID: "UTC")
    try state.mark(.completed, at: now, timeZoneID: "UTC")
    let before = state
    let view = try ActivityPlanPresentation(state: state, now: now, timeZoneID: "UTC")
    #expect(view.mode == .automatic)
    #expect(view.days.first { $0.isToday }?.entry?.status == .completed)
    #expect(state == before)
}

@Test func activityPresentationEmptyExposesSetupState_TC_ACTUI_001() throws {
    let state = PlanningState()
    let view = try ActivityPlanPresentation(state: state, now: date("2026-10-22T12:00:00Z"), timeZoneID: "UTC")
    #expect(view.mode == .unconfigured)
    #expect(!view.hasPlan)
    #expect(view.days.count == 7)
    #expect(view.days.allSatisfy { $0.entry == nil })
    #expect(view.pendingAutomaticStart == nil)
}

@Test func activityPresentationFutureAutomaticIsNotTodayMode_TC_ACTUI_001() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    try state.configurePlan(MovementPlan(goal: .active, weekdays: Set(1...7), activity: "手动", minutes: 15), at: now, timeZoneID: "UTC")
    let start = date("2026-10-23T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    try state.acceptAutomatic(AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC"), at: now, timeZoneID: "UTC")
    let before = state
    let view = try ActivityPlanPresentation(state: state, now: now, timeZoneID: "UTC")
    #expect(view.mode == .manual)
    #expect(view.pendingAutomaticStart == start)
    #expect(view.days.first { $0.isToday }?.entry?.activity == "手动")
    let tomorrow = try ActivityPlanPresentation(state: state, now: start, timeZoneID: "UTC")
    #expect(tomorrow.mode == .automatic)
    #expect(tomorrow.pendingAutomaticStart == nil)
    #expect(state == before)
}

@Test func activityPresentationCanceledFutureIsNotAdvertised_TC_ACTUI_002() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    let week = try AutomaticWeekPlanner.generate(config, starting: date("2026-10-23T00:00:00Z"), timeZoneID: "UTC")
    try state.acceptAutomatic(week, at: now, timeZoneID: "UTC")
    try state.switchToManual(at: now, timeZoneID: "UTC")
    let view = try ActivityPlanPresentation(state: state, now: now, timeZoneID: "UTC")
    #expect(view.pendingAutomaticStart == nil)
    #expect(view.hasPlan)
}

@Test func activityPresentationPreservesProcessedDayAndPausedMode_TC_ACTUI_003() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    try state.configurePlan(MovementPlan(goal: .active, weekdays: Set(1...7), activity: "手动", minutes: 15), at: now, timeZoneID: "UTC")
    try state.mark(.rested, at: now, timeZoneID: "UTC")
    var paused = try #require(state.plan)
    paused.status = .paused
    try state.configurePlan(paused, at: now, timeZoneID: "UTC")
    let view = try ActivityPlanPresentation(state: state, now: now, timeZoneID: "UTC")
    #expect(view.mode == .paused)
    #expect(view.days.first { $0.isToday }?.entry?.status == .rested)
    #expect(view.hasPlan)
}

@Test func activityPresentationWeekUsesAnalysisDaysAcrossDST_TC_ACTUI_004() throws {
    let now = date("2026-11-01T09:30:00Z")
    let view = try ActivityPlanPresentation(state: PlanningState(), now: now, timeZoneID: "America/Los_Angeles")
    let clock = try AnalysisClock(timeZoneID: "America/Los_Angeles")
    #expect(clock.label(view.days[0].date) == "2026-10-26")
    #expect(clock.label(view.days[6].date) == "2026-11-01")
    #expect(view.days.filter(\.isToday).count == 1)
    #expect(clock.day(containing: view.days[6].date).duration == 25 * 3600)
}
