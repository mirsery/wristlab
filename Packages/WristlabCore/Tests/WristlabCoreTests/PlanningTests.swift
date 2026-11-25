import Foundation
import Testing
@testable import WristlabCore

@Test func pausedWeightGoalStillAcceptsRecordsAndPreservesHistory() async throws {
    let now = date("2026-10-22T12:00:00Z")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    let repository = try HealthRepository(file: file)
    var planning = PlanningState()
    planning.weightGoals = [WeightGoal(startKilograms: 80, targetKilograms: 76, start: now, deadline: now.addingTimeInterval(86400), status: .paused)]
    let original = planning.weightGoals[0]
    planning.weights = [WeightEntry(kilograms: 79, at: now, recordedAt: now)]
    let initial = await repository.current()
    let saved = try await repository.savePlanning(planning, asOf: now, expectedRevision: initial.revision)
    #expect(saved.planning?.goal?.status == .paused)
    #expect(saved.planning?.weights.count == 1)
    planning.weightGoals.append(WeightGoal(startKilograms: 79, targetKilograms: 75, start: now, deadline: now.addingTimeInterval(172800)))
    let changed = try await repository.savePlanning(planning, asOf: now, expectedRevision: saved.revision)
    #expect(changed.planning?.weightGoals.first == original)
    #expect(changed.planning?.goal?.targetKilograms == 75)
    let recalculated = try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: changed.revision)
    #expect(recalculated.planning == planning)
    let configured = try await repository.configure(recalculated.profile, asOf: now)
    #expect(configured.planning == planning)
    let derivedClear = try await repository.clear(stopReading: false, asOf: now)
    #expect(derivedClear.planning == planning)
}

@Test func movementSuggestionHonorsPauseRestAndCompletionBeforeMetrics() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    #expect(try PlanSuggestion(state: state, report: nil, now: now, timeZoneID: "UTC").activity == nil)
    state.plan = MovementPlan(goal: .active, weekdays: [2], activity: "步行", minutes: 30)
    #expect(try PlanSuggestion(state: state, report: nil, now: now, timeZoneID: "UTC").activity == nil)
    state.plan?.weekdays = Set(1...7)
    try state.mark(.completed, at: now, timeZoneID: "UTC")
    #expect(try PlanSuggestion(state: state, report: nil, now: now, timeZoneID: "UTC").message.contains("已手动标记完成"))
    try state.mark(.rested, at: now, timeZoneID: "UTC")
    #expect(try PlanSuggestion(state: state, report: nil, now: now, timeZoneID: "UTC").message.contains("今天选择休息"))
    state.plan?.status = .paused
    #expect(try PlanSuggestion(state: state, report: nil, now: now, timeZoneID: "UTC").message.contains("已暂停"))
}

@Test func demoPlanningNeverAppearsInPublishedSnapshot() throws {
    let report = try DemoData.report()
    let planning = PlanningState.demo(at: report.asOf, timeZoneID: report.timeZoneID)
    try planning.validate(asOf: report.asOf)
    let snapshot = DisplaySnapshot(report: report, producerID: "synthetic-producer", epoch: 0, sequence: 0)
    let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    #expect(encoded["planning"] == nil)
    #expect(encoded["weights"] == nil)
    #expect(encoded["weightGoals"] == nil)
}

@Test func planningLowReadinessOnlyOffersPresetAlternative() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    state.plan = MovementPlan(goal: .active, weekdays: [5], activity: "步行", minutes: 30, lightActivity: "舒缓活动", lightMinutes: 10)
    var report = try DemoData.report()
    report.day = now
    report.asOf = now
    report.readiness.rawValue = 20
    report.readiness.availability = .available
    report.readiness.effectiveAt = now
    report.readiness.validUntil = now.addingTimeInterval(3600)
    let suggestion = try PlanSuggestion(state: state, report: report, now: now, timeZoneID: "UTC")
    #expect(suggestion.canChooseLight)
    #expect(suggestion.activity == "步行")
    #expect(suggestion.minutes == 30)
    report.readiness.validUntil = now.addingTimeInterval(-1)
    #expect(try !PlanSuggestion(state: state, report: report, now: now, timeZoneID: "UTC").canChooseLight)
}

@Test func planningExecutionPreservesSnapshotAndIsIdempotent() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    state.plan = MovementPlan(goal: .active, weekdays: [5], activity: "步行", minutes: 30)
    try state.mark(.completed, at: now, timeZoneID: "UTC")
    state.plan?.activity = "骑行"
    try state.mark(.completed, at: now, timeZoneID: "UTC")
    #expect(state.entries.count == 1)
    #expect(state.entries.first?.activity == "步行")
    #expect(state.entries.first?.status == .completed)
}

@Test func weightWeeklyMeanCountsDaysAndPreservesGaps() throws {
    let now = date("2026-10-22T12:00:00Z")
    let records = [
        WeightEntry(kilograms: 80, at: date("2026-10-19T08:00:00Z"), recordedAt: now),
        WeightEntry(kilograms: 79, at: date("2026-10-19T09:00:00Z"), recordedAt: now),
        WeightEntry(kilograms: 78, at: date("2026-10-20T09:00:00Z"), recordedAt: now),
        WeightEntry(kilograms: 77, at: date("2026-10-21T09:00:00Z"), recordedAt: now)
    ]
    let result = try WeightProgress(records: records, now: now, timeZoneID: "UTC")
    #expect(result.currentWeekDays == 3)
    #expect(result.currentWeekMean == 78)
    #expect(result.days.count == 3)
    #expect(try WeightProgress(records: Array(records.prefix(3)), now: now, timeZoneID: "UTC").currentWeekMean == nil)
}

@Test func weightValidationAndConversion() throws {
    #expect(abs(WeightUnit.pounds.kilograms(100) - 45.359237) < 0.000001)
    #expect(abs(WeightUnit.pounds.display(45.359237) - 100) < 0.000001)
    var state = PlanningState()
    state.weights = [WeightEntry(kilograms: .nan, at: Date(), recordedAt: Date())]
    #expect(throws: DomainError.self) { try state.validate(asOf: Date()) }
}

@Test func planningMigrationAndClearPreserveManualState() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    let repository = try HealthRepository(file: file)
    let before = await repository.current()
    var planning = PlanningState()
    planning.plan = MovementPlan(goal: .active, weekdays: [2], activity: "步行", minutes: 30)
    let saved = try await repository.savePlanning(planning, asOf: Date(), expectedRevision: before.revision)
    #expect(saved.planning?.plan?.minutes == 30)
    let recalculated = try await repository.clear(stopReading: false, asOf: Date())
    #expect(recalculated.planning?.plan != nil)
    _ = try await repository.clear(stopReading: true, asOf: Date())
    let cleared = await repository.current()
    #expect(cleared.planning == nil)
    do {
        _ = try await repository.apply(RecordBatch(additions: []), asOf: Date(), expectedRevision: saved.revision)
        Issue.record("Stale health refresh revived cleared data")
    } catch DomainError.staleRevision {}
    let reopened = try HealthRepository(file: file)
    #expect(await reopened.current().planning == nil)
    do {
        _ = try await repository.savePlanning(planning, asOf: Date(), expectedRevision: saved.revision)
        Issue.record("Stale planning write revived cleared data")
    } catch DomainError.staleRevision {}
}

@Test func planningRejectsCorruptHistoryAndProcessedLightReplacement() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    let plan = MovementPlan(goal: .active, weekdays: Set(1...7), activity: "步行", minutes: 30, lightActivity: "舒缓", lightMinutes: 10)
    try state.configurePlan(plan, at: now, timeZoneID: "UTC")
    try state.mark(.completed, at: now, timeZoneID: "UTC")
    #expect(throws: DomainError.self) { try state.mark(.planned, at: now, timeZoneID: "UTC", useLight: true) }
    state.planHistory[0].fromDay = "not-a-day"
    #expect(throws: DomainError.self) { try state.validate(asOf: now) }
    state.planHistory[0].fromDay = "2026-10-22"
    state.planHistory[0].plan.minutes = 0
    #expect(throws: DomainError.self) { try state.validate(asOf: now) }
}

@Test(arguments: [32.49, 32.5, 80.0])
func planningUsesDisplayedReadinessBoundary(_ raw: Double) throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    state.plan = MovementPlan(goal: .fitness, weekdays: Set(1...7), activity: "步行", minutes: 30, lightActivity: "舒缓", lightMinutes: 10)
    var report = try DemoData.report(); report.day = now; report.asOf = now
    report.readiness = MetricEstimate(raw, effectiveAt: now, validUntil: now.addingTimeInterval(3600))
    #expect(try PlanSuggestion(state: state, report: report, now: now, timeZoneID: "UTC").canChooseLight == (raw < 32.5))
    report.day = now.addingTimeInterval(-86400)
    #expect(try !PlanSuggestion(state: state, report: report, now: now, timeZoneID: "UTC").canChooseLight)
    report.day = now; report.readiness.availability = .calibrating
    #expect(try !PlanSuggestion(state: state, report: report, now: now, timeZoneID: "UTC").canChooseLight)
}

@Test func weightTrendSplitsRealGapsAndNeedsBothWeekMeans() throws {
    let now = date("2026-10-22T12:00:00Z")
    let records = ["2026-10-12", "2026-10-13", "2026-10-15", "2026-10-19", "2026-10-20", "2026-10-22"].enumerated().map { index, day in
        WeightEntry(id: "synthetic-\(index)", kilograms: index < 3 ? 80 : 79, at: date(day + "T08:00:00Z"), recordedAt: now)
    }
    let result = try WeightProgress(records: records, now: now, timeZoneID: "UTC")
    #expect(result.difference == -1)
    #expect(result.days[0].segment == result.days[1].segment)
    #expect(result.days[1].segment != result.days[2].segment)
    #expect(try WeightProgress(records: Array(records.dropFirst()), now: now, timeZoneID: "UTC").difference == nil)
}

@Test func planningEditsPreservePastAndCompletedSnapshots() throws {
    let monday = date("2026-10-19T12:00:00Z")
    let thursday = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    let first = MovementPlan(goal: .active, weekdays: Set(1...7), activity: "步行", minutes: 30)
    try state.configurePlan(first, at: monday, timeZoneID: "UTC")
    try state.mark(.completed, at: thursday, timeZoneID: "UTC")
    var second = first; second.activity = "骑行"
    try state.configurePlan(second, at: thursday, timeZoneID: "UTC")
    #expect(try state.scheduledEntry(at: monday, timeZoneID: "UTC")?.activity == "步行")
    #expect(try state.scheduledEntry(at: thursday, timeZoneID: "UTC")?.activity == "步行")
    #expect(try state.scheduledEntry(at: date("2026-10-23T12:00:00Z"), timeZoneID: "UTC")?.activity == "骑行")
    #expect(try state.scheduledEntry(at: date("2026-10-18T12:00:00Z"), timeZoneID: "UTC") == nil)
    try state.mark(.planned, at: thursday, timeZoneID: "UTC")
    try state.replaceToday(activity: "瑜伽", minutes: 20, at: thursday, timeZoneID: "UTC")
    #expect(state.entries.first?.status == .planned)
    #expect(state.entries.first?.activity == "瑜伽")
    state.plan?.status = .paused
    #expect(throws: DomainError.self) { try state.mark(.completed, at: thursday, timeZoneID: "UTC") }
}

@Test func weightWeekUsesAnalysisTimeZoneAndDST() throws {
    let now = date("2026-11-02T04:30:00Z")
    let records = ["2026-10-30T12:00:00Z", "2026-10-31T12:00:00Z", "2026-11-01T12:00:00Z"].enumerated().map {
        WeightEntry(id: "synthetic-\($0.offset)", kilograms: 80, at: date($0.element), recordedAt: now)
    }
    let local = try WeightProgress(records: records, now: now, timeZoneID: "America/New_York")
    let utc = try WeightProgress(records: records, now: now, timeZoneID: "UTC")
    #expect(local.currentWeekDays == 3)
    #expect(utc.currentWeekDays == 0)
    #expect(utc.previousWeekMean == 80)
    #expect(Set(local.days.map(\.segment)).count == 1)
}

@Test func weightGoalRejectsInvalidDatesAndPositiveValues() throws {
    let now = date("2026-10-22T12:00:00Z")
    var state = PlanningState()
    state.weightGoals = [WeightGoal(startKilograms: 80, targetKilograms: 76, start: now, deadline: now.addingTimeInterval(86400))]
    try state.validate(asOf: now)
    state.weightGoals[0].targetKilograms = 81
    #expect(throws: DomainError.self) { try state.validate(asOf: now) }
    state.weightGoals[0].targetKilograms = 76
    state.weightGoals[0].deadline = now
    #expect(throws: DomainError.self) { try state.validate(asOf: now) }
    state.weightGoals = []
    state.weights = [WeightEntry(kilograms: 80, at: now.addingTimeInterval(1), recordedAt: now)]
    #expect(throws: DomainError.self) { try state.validate(asOf: now) }
}

@Test func weightDeletionAndSameTimestampTieAreDeterministic() throws {
    let now = date("2026-10-22T12:00:00Z")
    var records = [
        WeightEntry(id: "synthetic-a", kilograms: 80, at: now, recordedAt: now),
        WeightEntry(id: "synthetic-b", kilograms: 79, at: now, recordedAt: now)
    ]
    #expect(try WeightProgress(records: records, now: now, timeZoneID: "UTC").days.last?.kilograms == 79)
    records.removeLast()
    #expect(try WeightProgress(records: records, now: now, timeZoneID: "UTC").days.last?.kilograms == 80)
}

@Test func planningOldCacheMigratesAndFailedCommitKeepsState() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = folder.appendingPathComponent("state.json")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(RepositoryState(profile: HealthProfile()))
    var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    legacy.removeValue(forKey: "planning")
    try JSONSerialization.data(withJSONObject: legacy).write(to: file)
    let repository = try HealthRepository(file: file)
    let old = await repository.current()
    #expect(old.planning == nil)
    var planning = PlanningState()
    planning.plan = MovementPlan(goal: .active, weekdays: [2], activity: "步行", minutes: 30)
    _ = try await repository.savePlanning(planning, asOf: Date(), expectedRevision: old.revision)
    let reopened = try HealthRepository(file: file)
    let persisted = await reopened.current()
    #expect(persisted.planning?.plan?.activity == "步行")
    try FileManager.default.removeItem(at: file)
    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
    do {
        _ = try await repository.savePlanning(PlanningState(), asOf: Date(), expectedRevision: persisted.revision)
        Issue.record("Expected atomic commit failure")
    } catch {
        let unchanged = await repository.current()
        #expect(unchanged.planning == persisted.planning)
        #expect(unchanged.revision == persisted.revision)
    }
}
