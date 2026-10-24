import Foundation
import Testing
@testable import WristlabCore

@Test func automaticCompletionUsesPreferredDuplicateSourceAndKeepsOtherTypeSeparate() throws {
    let now = date("2026-10-22T12:00:00Z")
    let preferred = SampleSource(bundle: "synthetic.preferred", family: "Watch", rank: 1)
    var original = HealthRecord(id: "synthetic-original", kind: .workout, start: now.addingTimeInterval(-1800), end: now, workoutType: "52", source: testSource)
    original.workoutDurationSeconds = 1800
    original.workoutActiveIntervals = [original.interval]
    var duplicate = HealthRecord(id: "synthetic-preferred", kind: .workout, start: original.start, end: original.end, workoutType: "52", source: preferred)
    duplicate.workoutDurationSeconds = 1200
    duplicate.workoutActiveIntervals = [DateInterval(start: duplicate.start, duration: 1200)]
    var other = original
    other.id = "synthetic-cycle"
    other.workoutType = "13"
    var profile = HealthProfile(timeZoneID: "UTC")
    profile.preferredSources[.workout] = [preferred.group]
    let result = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [original, duplicate, other], profile: profile, asOf: now)
    #expect(result.observedSeconds == 1200)
    #expect(result.sources == [preferred.group])
    #expect(!result.completed)
    #expect(result.otherRecords == 1)
    #expect(result.notes.first?.id == other.id)
    profile.preferredSources[.workout] = [testSource.group]
    let changed = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [original, duplicate, other], profile: profile, asOf: now)
    #expect(changed.observedSeconds == 1800)
    #expect(changed.completed)
}

@Test func automaticRepositoryReopensAndClearProtectsAgainstStaleWrites() async throws {
    let now = date("2026-10-22T12:00:00Z")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("automatic-state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let repository = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    var planning = PlanningState()
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    let week = try AutomaticWeekPlanner.generate(config, starting: date("2026-10-23T00:00:00Z"), timeZoneID: "UTC")
    try planning.acceptAutomatic(week, at: now, timeZoneID: "UTC")
    let initial = await repository.current()
    let saved = try await repository.savePlanning(planning, asOf: now, expectedRevision: initial.revision)
    let reopened = try HealthRepository(file: file)
    #expect(await reopened.current().planning == planning)
    let refreshed = try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: saved.revision)
    #expect(refreshed.planning == planning)
    let configured = try await repository.configure(refreshed.profile, asOf: now)
    #expect(configured.planning == planning)
    let derivedClear = try await repository.clear(stopReading: false, asOf: now)
    #expect(derivedClear.planning == planning)
    let retained = try HealthRepository(file: file)
    #expect(await retained.current().planning == planning)
    _ = try await repository.clear(stopReading: true, asOf: now)
    do {
        _ = try await repository.savePlanning(planning, asOf: now, expectedRevision: derivedClear.revision)
        Issue.record("Stale automatic plan revived cleared data")
    } catch DomainError.staleRevision {}
    do {
        _ = try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: derivedClear.revision)
        Issue.record("Stale health refresh overwrote automatic plan clear")
    } catch DomainError.staleRevision {}
    let erased = try HealthRepository(file: file)
    #expect(await erased.current().planning == nil)
}

@Test(arguments: [MovementStatus.completed, .rested])
func automaticWorkoutRefreshPreservesExplicitStatus(_ status: MovementStatus) async throws {
    let now = date("2026-10-22T12:00:00Z")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("manual-status.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let repository = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    var planning = PlanningState()
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    let week = try AutomaticWeekPlanner.generate(config, starting: date("2026-10-22T00:00:00Z"), timeZoneID: "UTC")
    try planning.acceptAutomatic(week, at: now.addingTimeInterval(-86400), timeZoneID: "UTC")
    try planning.mark(status, at: now, timeZoneID: "UTC")
    let entry = try #require(try planning.scheduledEntry(at: now, timeZoneID: "UTC"))
    let initial = await repository.current()
    let saved = try await repository.savePlanning(planning, asOf: now, expectedRevision: initial.revision)
    var record = HealthRecord(id: "synthetic-status", kind: .workout, start: now.addingTimeInterval(-3600), end: now, workoutType: "52", source: testSource)
    record.workoutDurationSeconds = 3600
    record.workoutActiveIntervals = [record.interval]
    let completed = try await repository.apply(RecordBatch(additions: [record]), asOf: now, expectedRevision: saved.revision)
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: entry.minutes, day: now, records: completed.records, profile: completed.profile, asOf: now).completed)
    #expect(completed.planning?.entries == planning.entries)
    let deleted = try await repository.apply(RecordBatch(additions: [], deletions: [record.id]), asOf: now, expectedRevision: completed.revision)
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: entry.minutes, day: now, records: deleted.records, profile: deleted.profile, asOf: now).observedSeconds == nil)
    #expect(try deleted.planning?.scheduledEntry(at: now, timeZoneID: "UTC")?.status == status)
    #expect(deleted.planning == planning)
}

@Test(arguments: [WeekFeedback.none, .suitable, .easy, .hard])
func automaticNextWeekHonorsConfirmationThreshold(_ feedback: WeekFeedback) throws {
    let start = date("2026-10-19T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: [2, 3, 4, 5, 6], maximumMinutes: 30)
    let previous = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    let now = date("2026-10-26T00:00:00Z")
    let sufficient = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: feedback, confirmedDays: 5, completedDays: 4, now: now)
    #expect(sufficient.totalMinutes == (feedback == .easy ? 55 : feedback == .hard ? 45 : 50))
    let insufficient = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: feedback, confirmedDays: 5, completedDays: 3, now: now)
    #expect(insufficient.totalMinutes == (feedback == .hard ? 45 : 50))
    let unconfirmed = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: feedback, confirmedDays: 4, completedDays: 4, now: now)
    #expect(unconfirmed.totalMinutes == (feedback == .hard ? 45 : 50))
}

@Test func workoutPauseValidationRejectsMalformedEvents() {
    let start = date("2026-10-22T10:00:00Z")
    let end = start.addingTimeInterval(1800)
    let pause = WorkoutPauseEvent(at: start.addingTimeInterval(600), paused: true)
    #expect(WorkoutActiveTime.intervals(start: start, end: end, duration: 600, events: [pause])?.first?.duration == 600)
    #expect(WorkoutActiveTime.intervals(start: start, end: end, duration: 600, events: [pause, pause]) == nil)
    #expect(WorkoutActiveTime.intervals(start: start, end: end, duration: 1800, events: [WorkoutPauseEvent(at: start, paused: false)]) == nil)
}

@Test(arguments: ["2026-03-08T08:00:00Z", "2026-11-01T07:00:00Z"])
func workoutCompletionClipsActualDSTDay(_ timestamp: String) throws {
    let start = date(timestamp)
    let clock = try AnalysisClock(timeZoneID: "America/Los_Angeles")
    let day = clock.day(containing: start)
    var record = HealthRecord(id: "synthetic-dst", kind: .workout, start: day.start.addingTimeInterval(-600), end: day.end.addingTimeInterval(600), workoutType: "52", source: testSource)
    record.workoutDurationSeconds = record.interval.duration
    record.workoutActiveIntervals = [record.interval]
    let result = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: start, records: [record], profile: HealthProfile(timeZoneID: "America/Los_Angeles"), asOf: record.end)
    #expect(result.observedSeconds == day.duration)
    #expect(day.duration == (timestamp.contains("03-08") ? 23 : 25) * 3600)
}

@Test func automaticRepeatedAcceptanceUsesLatestRevision() throws {
    let start = date("2026-10-26T00:00:00Z")
    let now = start.addingTimeInterval(-86400)
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: [2, 4], maximumMinutes: 30)
    let original = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    var edited = original
    edited.sessions[0].minutes = 20
    var state = PlanningState()
    try state.acceptAutomatic(original, at: now, timeZoneID: "UTC")
    try state.acceptAutomatic(edited, at: now, timeZoneID: "UTC")
    try state.acceptAutomatic(original, at: now, timeZoneID: "UTC")
    #expect(state.automatic?.weeks.count == 3)
    #expect(Set(state.automatic?.weeks.map(\.id) ?? []).count == 3)
    #expect(try state.scheduledEntry(at: start, timeZoneID: "UTC")?.minutes == 10)
    let decoded = try JSONDecoder().decode(PlanningState.self, from: JSONEncoder().encode(state))
    #expect(decoded == state)
}

@Test func workoutRevisionRecomputesAfterRevisionAndDeletion() throws {
    let now = date("2026-10-22T12:00:00Z")
    var record = HealthRecord(id: "synthetic-revision", kind: .workout, start: now.addingTimeInterval(-1800), end: now, workoutType: "52", source: testSource)
    record.workoutDurationSeconds = 1800
    record.workoutActiveIntervals = [record.interval]
    let profile = HealthProfile(timeZoneID: "UTC")
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [record], profile: profile, asOf: now).completed)
    record.workoutDurationSeconds = 1200
    record.workoutActiveIntervals = [DateInterval(start: record.start, duration: 1200)]
    #expect(try !WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [record], profile: profile, asOf: now).completed)
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [], profile: profile, asOf: now).observedSeconds == nil)
}

@Test func automaticWeekStartsTomorrowAndDeadlineDoesNotIncreaseDose() throws {
    let start = date("2026-10-23T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .regular, activities: [.walking, .cycling], weekdays: Set(1...7), maximumMinutes: 30)
    let ordinary = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    let short = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC", ending: date("2026-10-24T00:00:00Z"))
    #expect(ordinary.sessions.allSatisfy { $0.day >= start })
    #expect(short.sessions.allSatisfy { $0.day <= date("2026-10-24T00:00:00Z") })
    #expect(short.totalMinutes <= ordinary.totalMinutes)
    var invalid = config; invalid.weekdays = []
    #expect(throws: DomainError.self) { try AutomaticWeekPlanner.generate(invalid, starting: start, timeZoneID: "UTC") }
}

@Test func automaticNextWeekNeedsEvidenceAndAcceptance() throws {
    let start = date("2026-10-19T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: [2, 4, 6], maximumMinutes: 30)
    let previous = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    let now = date("2026-10-26T00:00:00Z")
    let increased = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: .easy, confirmedDays: 3, completedDays: 3, now: now)
    #expect(increased.totalMinutes == 35)
    #expect(increased.adjustment?.feedback == .easy)
    let unknown = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: .easy, confirmedDays: 2, completedDays: 2, now: now)
    #expect(unknown.totalMinutes == 30)
    let hard = try AutomaticWeekPlanner.nextWeek(after: previous, feedback: .hard, confirmedDays: 0, completedDays: 0, now: now)
    #expect(hard.totalMinutes == 25)
    #expect(throws: DomainError.self) {
        try AutomaticWeekPlanner.nextWeek(after: previous, feedback: .easy, confirmedDays: 3, completedDays: 3, now: start)
    }
}

@Test func automaticManualModeSwitchKeepsHistoricalSchedule() throws {
    let monday = date("2026-10-19T00:00:00Z")
    var state = PlanningState()
    try state.configurePlan(MovementPlan(goal: .active, weekdays: Set(1...7), activity: "手动", minutes: 15), at: monday, timeZoneID: "UTC")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
    let week = try AutomaticWeekPlanner.generate(config, starting: date("2026-10-21T00:00:00Z"), timeZoneID: "UTC")
    try state.acceptAutomatic(week, at: date("2026-10-20T00:00:00Z"), timeZoneID: "UTC")
    #expect(try state.scheduledEntry(at: monday, timeZoneID: "UTC")?.activity == "手动")
    try state.switchToManual(at: date("2026-10-23T00:00:00Z"), timeZoneID: "UTC")
    #expect(try state.scheduledEntry(at: date("2026-10-21T00:00:00Z"), timeZoneID: "UTC")?.activity == "步行")
    #expect(try state.scheduledEntry(at: date("2026-10-23T00:00:00Z"), timeZoneID: "UTC")?.activity == "手动")
}

@Test func workoutCompletionUnionsOverlapsAndClipsMidnight() throws {
    let now = date("2026-10-22T12:00:00Z")
    var first = HealthRecord(id: "synthetic-first", kind: .workout, start: date("2026-10-21T23:50:00Z"), end: date("2026-10-22T00:20:00Z"), workoutType: "52", source: testSource)
    first.workoutDurationSeconds = 1800; first.workoutActiveIntervals = [first.interval]
    var second = HealthRecord(id: "synthetic-second", kind: .workout, start: date("2026-10-22T00:05:00Z"), end: date("2026-10-22T00:25:00Z"), workoutType: "52", source: testSource)
    second.workoutDurationSeconds = 1200; second.workoutActiveIntervals = [second.interval]
    let result = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [first, second], profile: HealthProfile(timeZoneID: "UTC"), asOf: now)
    #expect(result.observedSeconds == 1500)
    #expect(!result.completed)
    let deleted = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [second], profile: HealthProfile(timeZoneID: "UTC"), asOf: now)
    #expect(deleted.observedSeconds == 1200)
}

@Test func workoutLegacyFieldsRemainMissingAndCanBeRebuilt() throws {
    let now = date("2026-10-22T12:00:00Z")
    let record = HealthRecord(id: "synthetic-legacy", kind: .workout, start: now.addingTimeInterval(-1800), end: now, workoutType: "52", source: testSource)
    let encoded = try JSONEncoder().encode(record)
    var old = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    old.removeValue(forKey: "workoutActiveIntervals"); old.removeValue(forKey: "workoutDurationSeconds")
    let legacy = try JSONDecoder().decode(HealthRecord.self, from: JSONSerialization.data(withJSONObject: old))
    let progress = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [legacy], profile: HealthProfile(timeZoneID: "UTC"), asOf: now)
    #expect(progress.observedSeconds == nil)
    #expect(progress.excludedRecords == 1)
    var wrongType = legacy; wrongType.workoutType = "13"
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [wrongType], profile: HealthProfile(timeZoneID: "UTC"), asOf: now).otherRecords == 1)
}

@Test func workoutToleranceNeverCompletesBeforeDurationTarget() throws {
    let now = date("2026-10-22T12:00:00Z")
    var record = HealthRecord(id: "synthetic-rounding", kind: .workout, start: now.addingTimeInterval(-1800), end: now, workoutType: "52", source: testSource)
    record.workoutDurationSeconds = 1799.5; record.workoutActiveIntervals = [record.interval]
    let result = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [record], profile: HealthProfile(timeZoneID: "UTC"), asOf: now)
    #expect(result.observedSeconds == 1799.5)
    #expect(!result.completed)
}

@Test func automaticFieldsAreOptionalForPreviousPlanningCache() throws {
    var state = PlanningState()
    state.plan = MovementPlan(goal: .active, weekdays: [2], activity: "步行", minutes: 30)
    var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    old.removeValue(forKey: "automatic")
    let decoded = try JSONDecoder().decode(PlanningState.self, from: JSONSerialization.data(withJSONObject: old))
    #expect(decoded.automatic == nil)
    #expect(decoded.plan == state.plan)
}

@Test func automaticWeekRespectsCapacityAndIsDeterministic() throws {
    let start = date("2026-10-26T00:00:00Z")
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: [2, 4, 6], maximumMinutes: 30)
    let first = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    let repeated = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    #expect(first == repeated)
    #expect(first.sessions.map(\.minutes) == [10, 10, 10])
    #expect(first.totalMinutes == 30)
    var limited = config; limited.maximumMinutes = 7
    #expect(try AutomaticWeekPlanner.generate(limited, starting: start, timeZoneID: "UTC").sessions.allSatisfy { $0.minutes <= 7 })
}

@Test func automaticAcceptanceKeepsCompletedAndManualPlan() throws {
    let start = date("2026-10-26T00:00:00Z")
    var state = PlanningState()
    state.plan = MovementPlan(goal: .active, weekdays: [2], activity: "原手动安排", minutes: 15)
    let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: [2, 4], maximumMinutes: 30)
    let draft = try AutomaticWeekPlanner.generate(config, starting: start, timeZoneID: "UTC")
    try state.acceptAutomatic(draft, at: start.addingTimeInterval(-86400), timeZoneID: "UTC")
    #expect(state.plan?.activity == "原手动安排")
    #expect(try state.scheduledEntry(at: start, timeZoneID: "UTC")?.minutes == 10)
    try state.mark(.completed, at: start, timeZoneID: "UTC")
    #expect(state.entries.first?.status == .completed)
}

@Test func workoutEvidenceExcludesPausesAndRejectsAmbiguity() throws {
    let start = date("2026-10-22T10:00:00Z")
    let end = start.addingTimeInterval(2400)
    let events = [WorkoutPauseEvent(at: start.addingTimeInterval(600), paused: true), WorkoutPauseEvent(at: start.addingTimeInterval(1200), paused: false)]
    let intervals = try #require(WorkoutActiveTime.intervals(start: start, end: end, duration: 1800, events: events))
    #expect(intervals.reduce(0) { $0 + $1.duration } == 1800)
    #expect(WorkoutActiveTime.intervals(start: start, end: end, duration: 1800, events: []) == nil)
}

@Test(arguments: [1799.0, 1800.0, 1801.0])
func workoutCompletionUsesSecondsAndNeverInventsMissing(_ seconds: Double) throws {
    let now = date("2026-10-22T12:00:00Z")
    var record = HealthRecord(id: "synthetic-walk", kind: .workout, start: now.addingTimeInterval(-seconds), end: now, workoutType: "52", source: testSource)
    record.workoutDurationSeconds = seconds
    record.workoutActiveIntervals = [record.interval]
    let progress = try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [record, record], profile: HealthProfile(timeZoneID: "UTC"), asOf: now)
    #expect(progress.observedSeconds == seconds)
    #expect(progress.completed == (seconds >= 1800))
    #expect(try WorkoutCompletion(activity: .walking, targetMinutes: 30, day: now, records: [], profile: HealthProfile(timeZoneID: "UTC"), asOf: now).observedSeconds == nil)
}
