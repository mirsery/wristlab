import Foundation
import Testing
@testable import WristlabCore

@Test func readinessCalibrationAndConstantHistory_SCN001_002() {
    let history = Array(repeating: PhysiologyPair(hrv: 60, heartRate: 60), count: 14)
    #expect(Physiology.readiness(hrv: 60, rhr: 60, history: Array(history.prefix(13))).availability == .calibrating)
    #expect(Physiology.readiness(hrv: 60, rhr: 60, history: history).value == 50)
}

@Test func analysisDaysRespectDST_SCN020() throws {
    let clock = try AnalysisClock(timeZoneID: "America/New_York")
    let parser = ISO8601DateFormatter()
    let spring = parser.date(from: "2026-03-08T12:00:00Z")!
    let fall = parser.date(from: "2026-11-01T12:00:00Z")!
    #expect(clock.day(containing: spring).duration == 23 * 3600)
    #expect(clock.day(containing: fall).duration == 25 * 3600)
}

let testSource = SampleSource(bundle: "test.watch", family: "Watch", rank: 0)
func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
func sleepRecord(_ id: String, _ start: String, _ end: String, _ stage: SleepStage) -> HealthRecord {
    HealthRecord(id: id, kind: .sleep, start: date(start), end: date(end), stage: stage, source: testSource)
}
@Test func sleepDoesNotDoubleCountInBed_SCN014_015() throws {
    let clock = try AnalysisClock(timeZoneID: "UTC")
    let records = [
        sleepRecord("bed", "2026-10-19T23:00:00Z", "2026-10-20T07:00:00Z", .inBed),
        sleepRecord("core", "2026-10-19T23:30:00Z", "2026-10-20T03:00:00Z", .core),
        sleepRecord("deep", "2026-10-20T03:00:00Z", "2026-10-20T04:00:00Z", .deep),
        sleepRecord("rem", "2026-10-20T04:00:00Z", "2026-10-20T06:30:00Z", .rem)]
    let report = SleepCalculator.report(day: date("2026-10-20T14:00:00Z"), records: records,
                                        profile: HealthProfile(timeZoneID: "UTC"), clock: clock, asOf: date("2026-10-20T14:00:00Z"))
    #expect(report.totalMinutes == 420)
    #expect(report.inBedMinutes == 480)
    #expect(report.stages[.deep] == 60)
    #expect(report.efficiency == 0.875)
    let bedOnly = SleepCalculator.report(day: date("2026-10-20T14:00:00Z"), records: [records[0]],
                                         profile: HealthProfile(timeZoneID: "UTC"), clock: clock, asOf: date("2026-10-20T14:00:00Z"))
    #expect(bedOnly.totalMinutes == nil)
    #expect(bedOnly.primary == nil)
}

@Test func energyUsesMinuteStepsAndBreaksOnMissingObservation_SCN009_011() {
    #expect(abs(EnergyCalculator.step(energy: 50, context: .asleep, seconds: 60)! - 50.0666666667) < 1e-6)
    let start = Date(timeIntervalSince1970: 0)
    let seed = EnergySeed(at: start, value: 50)
    let short = EnergyCalculator.replay(seeds: [seed], asleep: [], workouts: [], stress: [], asOf: start.addingTimeInterval(1800))
    let long = EnergyCalculator.replay(seeds: [seed], asleep: [], workouts: [], stress: [], asOf: start.addingTimeInterval(1801))
    #expect(short.estimate.reasons.contains("lowCoverage"))
    #expect(long.estimate.reasons.contains("recalibrationRequired"))
}

@Test func activityDoesNotFillLongGapsAndTargetsRequireCompleteDays_SCN021_025() {
    #expect(ActivityCalculator.zone(hrr: 0.6) == 2)
    #expect(abs(ActivityCalculator.exertion(load: 60)! - 32.9679953964) < 1e-6)
    #expect(ActivityCalculator.target(lastSeven: [100,100,100,100,100,100,100], readiness: 50, mode: .maintain)?.lower == 80)
    #expect(ActivityCalculator.target(lastSeven: [100,100,nil,100,100,100,100], readiness: 50, mode: .maintain) == nil)
}

@Test func pipelineKeepsMissingDataMissingAndRejectsInvalidConfiguration_SCN029() throws {
    let report = try HealthEngine.evaluate(records: [], profile: HealthProfile(timeZoneID: "UTC"), asOf: date("2026-10-20T14:00:00Z"), inputRevision: 1)
    #expect(report.readiness.value == nil)
    #expect(report.energy.estimate.value == nil)
    #expect(report.activity.exertion.value == nil)
    #expect(throws: DomainError.self) {
        try HealthEngine.evaluate(records: [], profile: HealthProfile(timeZoneID: "Invalid"), asOf: date("2026-10-20T14:00:00Z"), inputRevision: 1)
    }
}

@Test func snapshotRejectsOldEpochAndDoesNotReviveClearedData_SCN027_028() throws {
    var receiver = SnapshotReceiver()
    let empty = try HealthEngine.evaluate(records: [], profile: HealthProfile(timeZoneID: "UTC"), asOf: date("2026-10-20T14:00:00Z"), inputRevision: 0)
    var fresh = DisplaySnapshot(report: empty, producerID: "phone", epoch: 2, sequence: 1)
    try receiver.accept(fresh, confirmProducer: true)
    var old = fresh; old.epoch = 1; old.sequence = 999
    #expect(throws: DomainError.self) { try receiver.accept(old) }
    fresh.epoch = 3; fresh.sequence = 0; fresh.clearData = true
    try receiver.accept(fresh)
    #expect(receiver.snapshot?.clearData == true)
    #expect(throws: DomainError.self) { try receiver.accept(old) }
}

@Test func syntheticHistoryProducesARealPipelineReportAndIsOrderIndependent() throws {
    let now = date("2026-10-20T14:00:00Z")
    let records = try DemoData.records(asOf: now)
    let profile = HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190)
    let first = try HealthEngine.evaluate(records: records, profile: profile, asOf: now, inputRevision: 1)
    let again = try HealthEngine.evaluate(records: records.reversed(), profile: profile, asOf: now, inputRevision: 1)
    #expect(first == again)
    #expect(first.readiness.value != nil)
    #expect(first.readiness.mode == "night")
    #expect(first.sleep.totalMinutes == 480)
    #expect(first.energy.estimate.value != nil)
    #expect(first.activity.day.load != nil)
}

@Test func repositoryCommitsAnchorsAndReportTogetherAndRejectsOldTasks() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("state.json")
    let repository = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    let now = date("2026-10-20T14:00:00Z")
    let result = try await repository.apply(RecordBatch(additions: [], anchors: ["hr": Data([1])]), asOf: now, expectedRevision: 0)
    #expect(result.revision == 1)
    let reopened = try HealthRepository(file: file)
    #expect(await reopened.current().anchors["hr"] == Data([1]))
    await #expect(throws: DomainError.self) {
        try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: 0)
    }
    let cleared = try await repository.clear(stopReading: true, asOf: now)
    #expect(cleared.snapshot?.clearData == true)
    #expect(!cleared.readingEnabled)
}

@Test func numericGoldenVectorsMatchSpecification() throws {
    let url = Bundle.module.url(forResource: "business-v1", withExtension: "json", subdirectory: "Fixtures")!
    let data = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    for vector in try #require(data["vectors"] as? [[String: Any]]) {
        let x = vector["input"] as! [String: Any], expected = vector["expected"] as! [String: Any]
        var actual: Double?
        switch vector["operation"] as! String {
        case "readiness":
            let history = Array(repeating: PhysiologyPair(hrv: 60, heartRate: 60), count: x["baselineDays"] as! Int)
            actual = Physiology.readiness(hrv: x["hrv"] as? Double, rhr: x["rhr"] as? Double, history: history).rawValue
        case "stress":
            actual = Physiology.stress(hr: x["hr"] as? Double, hrv: x["hrv"] as? Double, history: Array(repeating: PhysiologyPair(hrv: 60, heartRate: 60), count: 14)).rawValue
        case "batteryStep": actual = EnergyCalculator.step(energy: x["energy"] as! Double, context: x["context"] as! String == "asleep" ? .asleep : .workout, seconds: x["durationSeconds"] as! Double)
        case "exertion": actual = ActivityCalculator.exertion(load: x["observedLoad"] as! Double)
        case "targetRange":
            let range = ActivityCalculator.target(lastSeven: (x["last7CompleteLoads"] as! [Double]).map(Optional.some), readiness: x["readinessDisplay"] as? Int, mode: .maintain)
            #expect(abs(range!.lower - (expected["lower"] as! Double)) < 1e-6)
            actual = range?.upper
        case "sleepDebt": actual = SleepCalculator.debt(minutes: (x["sleepMinutes"] as! [Any]).map { $0 as? Double }, target: x["targetMinutes"] as! Double)
        case "regularity": actual = SleepCalculator.regularity(startClockMinutes: x["startClockMinutes"] as! [Double])
        default: Issue.record("Unknown fixture operation"); continue
        }
        let target = expected["raw"] ?? expected["upper"] ?? expected["minutes"] ?? expected["deviationMinutes"]!
        if target is NSNull { #expect(actual == nil) }
        else { #expect(abs((actual ?? .infinity) - (target as! Double)) <= 1e-6) }
    }
}

@Test func repositoryDoesNotRegressSampleVersions() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = try HealthRepository(file: file, profile: HealthProfile(timeZoneID: "UTC"))
    let now = date("2026-10-20T14:00:00Z")
    var sample = HealthRecord(id: "hr", kind: .heartRate, start: now, end: now, value: 70, source: testSource, version: 2)
    _ = try await store.apply(RecordBatch(additions: [sample]), asOf: now)
    sample.version = 1; sample.value = 90
    let updated = try await store.apply(RecordBatch(additions: [sample]), asOf: now)
    #expect(updated.records.first?.value == 70)
}
