import Testing
@testable import WristlabCore

@Test func activityBreakdownMissingDoesNotInventZoneMinutes() throws {
    var activity = try DemoData.report().activity
    activity.day = LoadSummary(load: nil, coverage: 0, zoneMinutes: [0, 0, 0, 0, 0, 0], intensity: nil, complete: false, aboveMaximum: false)
    let result = ActivityBreakdown(activity)
    #expect(result.day.zoneMinutes == nil)
    #expect(result.day.load == nil)
    #expect(!result.day.isLowerBound)
}

@Test func activityBreakdownPreservesObservedZeroAndPartialLoad() throws {
    var activity = try DemoData.report().activity
    activity.day = LoadSummary(load: 0, coverage: 0.25, zoneMinutes: [12, 0, 0, 0, 0, 0], intensity: nil, complete: false, aboveMaximum: false)
    let result = ActivityBreakdown(activity)
    #expect(result.day.load == 0)
    #expect(result.day.zoneMinutes == [12, 0, 0, 0, 0, 0])
    #expect(result.day.isLowerBound)
    #expect(result.day.coverage == 0.25)
}

@Test func activityBreakdownFullCoverageDistinguishesSettlement() throws {
    var activity = try DemoData.report().activity
    activity.day = LoadSummary(load: 0, coverage: 1, zoneMinutes: [20, 0, 0, 0, 0, 0], intensity: 0, complete: true, aboveMaximum: false)
    #expect(!ActivityBreakdown(activity).day.isLowerBound)
    #expect(ActivityBreakdown(activity).day.zoneMinutes == [20, 0, 0, 0, 0, 0])
    activity.day.complete = false
    #expect(ActivityBreakdown(activity).day.isLowerBound)
    #expect(ActivityBreakdown(activity).day.coverage == 1)
}

@Test func activityBreakdownMissingWorkoutDoesNotUseDailyLoad() throws {
    var activity = try DemoData.report().activity
    activity.workouts = ["synthetic-empty": LoadSummary(load: nil, coverage: 0, zoneMinutes: [0, 0, 0, 0, 0, 0], intensity: nil, complete: false, aboveMaximum: false)]
    let workout = try #require(ActivityBreakdown(activity).workouts.first)
    #expect(workout.detail.load == nil)
    #expect(workout.detail.zoneMinutes == nil)
    #expect(workout.detail.coverage == 0)
}

@Test func activityBreakdownWorkoutsUseStableNonChronologicalNumbers() throws {
    var activity = try DemoData.report().activity
    activity.workouts = ["synthetic-z": activity.day, "synthetic-a": activity.day]
    let result = ActivityBreakdown(activity)
    #expect(result.workouts.map(\.id) == ["synthetic-a", "synthetic-z"])
    #expect(result.workouts.map(\.number) == [1, 2])
}
