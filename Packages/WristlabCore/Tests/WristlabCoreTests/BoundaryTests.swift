import Foundation
import Testing
@testable import WristlabCore

@Test func normalizationRejectsInvalidFutureAndDuplicateInputs() {
    let now = date("2026-10-20T14:00:00Z")
    let sample = HealthRecord(id: "a", kind: .hrv, start: now, end: now, value: 60, source: testSource)
    var duplicate = sample; duplicate.id = "b"
    var invalid = sample; invalid.id = "invalid"; invalid.value = .nan
    var future = sample; future.id = "future"; future.end = now.addingTimeInterval(1)
    #expect(RecordNormalizer.normalize([duplicate, invalid, sample, future], asOf: now) == [sample])
}

@Test func nightCalibrationCannotBorrowDayBaselineAndFallbackCannotSeed_SCN004_005() throws {
    let now = date("2026-10-20T14:00:00Z"), clock = try AnalysisClock(timeZoneID: "UTC")
    let threshold = clock.shiftedDay(now, by: -13)
    let all = try DemoData.records(asOf: now)
    let records = all.filter { record in
        !(record.kind == .hrv && clock.calendar.component(.hour, from: record.end) < 8 && record.end < threshold)
    }
    let profile = HealthProfile(timeZoneID: "UTC")
    let night = try HealthEngine.evaluate(records: records, profile: profile, asOf: now, inputRevision: 1)
    #expect(night.readiness.mode == "night")
    #expect(night.readiness.baselineDays == 13)
    #expect(night.readiness.availability == .calibrating)
    let noSleep = all.filter { $0.kind != .sleep }
    let fallback = try HealthEngine.evaluate(records: noSleep, profile: profile, asOf: now, inputRevision: 1)
    #expect(fallback.readiness.mode == "dayFallback")
    #expect(fallback.readiness.value != nil)
    #expect(fallback.energy.estimate.value == nil)
}

@Test func stressMissingHRAndExpiryBoundary_SCN007_008() {
    let history = Array(repeating: PhysiologyPair(hrv: 60, heartRate: 60), count: 14)
    #expect(Physiology.stress(hr: nil, hrv: 60, history: history).value == nil)
    var metric = Physiology.stress(hr: 60, hrv: 60, history: history)
    let at = date("2026-10-20T10:00:00Z")
    metric.effectiveAt = at; metric.validUntil = at.addingTimeInterval(900)
    #expect(!metric.isStale(at: at.addingTimeInterval(900)))
    #expect(metric.isStale(at: at.addingTimeInterval(901)))
}

@Test func energyWorkoutWinsAndReplayDoesNotResetAtMidnight_SCN010_012() {
    let start = date("2026-10-19T23:59:00Z"), end = start.addingTimeInterval(120)
    let interval = DateInterval(start: start, end: end)
    let seeds = [EnergySeed(at: start, value: 50)]
    let full = EnergyCalculator.replay(seeds: seeds, asleep: [interval], workouts: [interval], stress: [], asOf: end)
    #expect(abs(full.estimate.rawValue! - 49.8002) < 1e-6)
    let replay = EnergyCalculator.replay(seeds: seeds, asleep: [interval, interval], workouts: [interval, interval], stress: [], asOf: end)
    #expect(full == replay)
}

@Test func sleepMergeBoundaryNapAndConflicts_SCN016_017() throws {
    let now = date("2026-10-20T14:00:00Z"), clock = try AnalysisClock(timeZoneID: "UTC"), profile = HealthProfile(timeZoneID: "UTC")
    let first = sleepRecord("one", "2026-10-20T00:00:00Z", "2026-10-20T02:00:00Z", .core)
    let second = sleepRecord("two", "2026-10-20T03:30:00Z", "2026-10-20T05:30:00Z", .deep)
    let merged = SleepCalculator.report(day: now, records: [first,second], profile: profile, clock: clock, asOf: now)
    #expect(merged.primary?.asleepMinutes == 240)
    var later = second; later.start = later.start.addingTimeInterval(1)
    let split = SleepCalculator.report(day: now, records: [first,later], profile: profile, clock: clock, asOf: now)
    #expect(split.primary == nil)
    #expect(split.naps.count == 2)
    let main = sleepRecord("main", "2026-10-20T00:00:00Z", "2026-10-20T06:00:00Z", .core)
    let nap = sleepRecord("nap", "2026-10-20T10:00:00Z", "2026-10-20T10:30:00Z", .unspecified)
    let report = SleepCalculator.report(day: now, records: [main,nap], profile: profile, clock: clock, asOf: now)
    #expect(report.totalMinutes == 390)
    #expect(report.primary?.asleepMinutes == 360)
    #expect(report.naps.first?.asleepMinutes == 30)
    let conflict = sleepRecord("conflict", "2026-10-20T02:00:00Z", "2026-10-20T03:00:00Z", .rem)
    let conflicted = SleepCalculator.report(day: now, records: [main,conflict], profile: profile, clock: clock, asOf: now)
    #expect(conflicted.reasons.contains("sourceConflict"))
    #expect(conflicted.totalMinutes == 300)
}

@Test func sleepPriorityAndOngoingDoNotCreateReadyPrimary_SCN030() throws {
    let now = date("2026-10-20T08:00:00Z"), clock = try AnalysisClock(timeZoneID: "UTC")
    let watch = sleepRecord("one", "2026-10-20T00:00:00Z", "2026-10-20T07:00:00Z", .core)
    var other = watch; other.id = "other"; other.source = SampleSource(bundle: "other", family: "Other", rank: 1); other.stage = .deep
    let profile = HealthProfile(timeZoneID: "UTC", preferredSources: [.sleep:[other.source.group]])
    let report = SleepCalculator.report(day: now, records: [watch,other], profile: profile, clock: clock, asOf: now)
    #expect(report.sourceGroup == other.source.group)
    #expect(report.primary == nil) // Only 60 minutes since sleep ended.
}

@Test func workoutDedupAndHRHoldLimit_SCN022_023_024() {
    #expect([0.5,0.6,0.7,0.8,0.9,1.0].map(ActivityCalculator.zone) == [1,2,3,4,5,5])
    let start = date("2026-10-20T09:00:00Z"), end = start.addingTimeInterval(1800)
    let workout = HealthRecord(id: "w", kind: .workout, start: start, end: end, workoutType: "run", source: testSource)
    var duplicate = workout; duplicate.id = "z"
    #expect(ActivityCalculator.deduplicatedWorkouts([workout,duplicate]).count == 1)
    let hr = HealthRecord(id: "h", kind: .heartRate, start: start, end: start, value: 138, source: testSource)
    let summary = ActivityCalculator.load(hr: [hr], windows: [DateInterval(start: start, end: end)], maximum: 180, resting: 60, asOf: end, settled: true)
    #expect(summary.load == 2)
    #expect(summary.coverage == 1.0/30)
    #expect(summary.intensity == nil)
    #expect(!summary.complete)
    #expect(ActivityCalculator.load(hr: [hr], windows: [DateInterval(start: start, end: end)], maximum: nil, resting: 60, asOf: end, settled: true).load == nil)
    #expect(ActivityCalculator.meanComplete([100,nil,100], count: 3) == nil)
}

@Test func malformedSnapshotsAndProducerSwitchPreserveOldValue_SCN030() throws {
    let report = try HealthEngine.evaluate(records: [], profile: HealthProfile(timeZoneID: "UTC"), asOf: date("2026-10-20T14:00:00Z"), inputRevision: 0)
    let original = DisplaySnapshot(report: report, producerID: "one", epoch: 0, sequence: 1)
    var receiver = SnapshotReceiver(); try receiver.accept(original, confirmProducer: true)
    var changed = original; changed.producerID = "two"
    #expect(throws: DomainError.self) { try receiver.accept(changed) }
    #expect(receiver.snapshot == original)
    changed = original; changed.schemaVersion = 999
    #expect(throws: DomainError.self) { try receiver.accept(changed) }
    changed = original; changed.energy.rawValue = 101; changed.energy.availability = .available
    #expect(throws: DomainError.self) { try receiver.accept(changed) }
    #expect(receiver.snapshot == original)
}

@Test func repositoryDeletionRebuildAndClearArePersistent_SCN013_031() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    let now = date("2026-10-20T14:00:00Z")
    let records = try DemoData.records(asOf: now)
    let initial = try await store.apply(RecordBatch(additions: records), asOf: now)
    let deleted = Set(records.filter { $0.kind == .sleep }.map(\.id))
    let updated = try await store.apply(RecordBatch(additions: [], deletions: deleted), asOf: now)
    #expect(initial.report?.readiness.mode == "night")
    #expect(updated.report?.readiness.mode == "dayFallback")
    #expect(updated.report?.energy.estimate.value == nil)
    let clear = try await store.clear(stopReading: true, asOf: now)
    let reopened = try HealthRepository(file: file)
    #expect(await reopened.current().snapshot == clear.snapshot)
    #expect(await reopened.current().records.isEmpty == true)
}

@Test func failedDiskCommitDoesNotAdvanceReportOrAnchor() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("state.json")
    let store = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    let now = date("2026-10-20T14:00:00Z")
    _ = try await store.apply(RecordBatch(additions: [], anchors: ["hr":Data([1])]), asOf: now)
    try FileManager.default.removeItem(at: folder)
    try Data([0]).write(to: folder)
    do {
        _ = try await store.apply(RecordBatch(additions: [], anchors: ["hr":Data([2])]), asOf: now)
        Issue.record("Writing into a file path should fail")
    } catch {}
    #expect(await store.current().revision == 1)
    #expect(await store.current().anchors["hr"] == Data([1]))
}

@Test func unchangedRefreshDoesNotCreateNewWireSnapshot() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = try HealthRepository(file: folder.appendingPathComponent("state.json"), profile: HealthProfile(timeZoneID: "UTC"))
    let now = date("2026-10-20T14:00:00Z")
    let first = try await store.apply(RecordBatch(additions: []), asOf: now)
    let second = try await store.apply(RecordBatch(additions: []), asOf: now.addingTimeInterval(1))
    #expect(first.snapshot == second.snapshot)
}
