import Foundation
import Testing
@testable import WristlabCore

private let retiredSource = SampleSource(bundle: "a.synthetic.retired", family: "Watch", rank: 0)

private func retiredQuantity(_ kind: HealthKind, at date: Date, id: String = "retired") -> HealthRecord {
    HealthRecord(id: id, kind: kind, start: date, end: date, value: kind == .hrv ? 60 : 70, source: retiredSource)
}

// TC-SOURCE-001: exercise the production engine, not just candidate sorting.
@Test func activeSourceRestoresCurrentStressAndEnergy_TC_SOURCE_001() throws {
    let now = DemoData.previewDate
    let records = try DemoData.records(asOf: now)
    let profile = HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190)
    let expected = try HealthEngine.evaluate(records: records, profile: profile, asOf: now, inputRevision: 1)
    let old = retiredQuantity(.heartRate, at: now.addingTimeInterval(-90 * 86400))
    let actual = try HealthEngine.evaluate(records: records + [old], profile: profile, asOf: now, inputRevision: 1)
    #expect(!actual.stressTimeline.isEmpty)
    #expect(actual.stress == expected.stress)
    #expect(actual.energy == expected.energy)
    #expect(actual.sourceSignature == expected.sourceSignature)
}

// TC-SOURCE-002: rank is unchanged and lower-ranked sources never fill gaps.
@Test func activeSourceRetainsRankAndSingleGroup_TC_SOURCE_002() throws {
    let now = DemoData.previewDate, clock = try AnalysisClock(timeZoneID: "UTC")
    let window = DateInterval(start: clock.shiftedDay(now, by: -60), end: now)
    let watch = SampleSource(bundle: "z.synthetic.watch", family: "Watch", rank: 0)
    let thirdParty = SampleSource(bundle: "a.synthetic.other", family: "Other", rank: 1)
    let phone = SampleSource(bundle: "a.synthetic.phone", family: "iPhone", rank: 2)
    let records = [
        HealthRecord(id: "watch", kind: .heartRate, start: now, end: now, value: 70, source: watch),
        HealthRecord(id: "old-same-watch", kind: .heartRate, start: window.start.addingTimeInterval(-86400), end: window.start.addingTimeInterval(-86400), value: 70, source: watch),
        HealthRecord(id: "gap-other", kind: .heartRate, start: now.addingTimeInterval(-300), end: now.addingTimeInterval(-300), value: 70, source: thirdParty),
        HealthRecord(id: "gap-phone", kind: .heartRate, start: now.addingTimeInterval(-600), end: now.addingTimeInterval(-600), value: 70, source: phone)
    ]
    let profile = HealthProfile(timeZoneID: "UTC")
    let chosen = RecordNormalizer.selected(records.reversed(), kind: .heartRate, profile: profile, sourceWindow: window)
    #expect(Set(chosen.map(\.id)) == ["watch", "old-same-watch"])
    let other = RecordNormalizer.selected(records.filter { $0.source != watch }, kind: .heartRate, profile: profile, sourceWindow: window)
    #expect(other.map(\.id) == ["gap-other"])
}

// TC-SOURCE-003: explicit old-source preference is intentional, per kind.
@Test func activeSourceRespectsPreferencesAndTypeIsolation_TC_SOURCE_003() throws {
    let now = DemoData.previewDate, clock = try AnalysisClock(timeZoneID: "UTC")
    let window = DateInterval(start: clock.shiftedDay(now, by: -60), end: now)
    let current = SampleSource(bundle: "z.synthetic.current", family: "Watch", rank: 0)
    var records: [HealthRecord] = []
    for kind in [HealthKind.heartRate, .restingHeartRate, .hrv] {
        records.append(retiredQuantity(kind, at: now.addingTimeInterval(-90 * 86400), id: "old-\(kind)"))
        records.append(HealthRecord(id: "new-\(kind)", kind: kind, start: now, end: now, value: 60, source: current))
    }
    let profile = HealthProfile(timeZoneID: "UTC", preferredSources: [.heartRate: ["missing/Watch", retiredSource.group]])
    #expect(RecordNormalizer.selected(records, kind: .heartRate, profile: profile, sourceWindow: window).first?.source == retiredSource)
    for kind in [HealthKind.restingHeartRate, .hrv] {
        #expect(RecordNormalizer.selected(records, kind: kind, profile: profile, sourceWindow: window).first?.source == current)
    }
}

// TC-SOURCE-004: use calendar-day bounds, including DST and exact endpoints.
@Test func activeSourceWindowBoundsAndValidity_TC_SOURCE_004() throws {
    let now = date("2026-11-02T14:00:00Z"), clock = try AnalysisClock(timeZoneID: "America/New_York")
    let window = DateInterval(start: clock.shiftedDay(now, by: -60), end: now)
    let profile = HealthProfile(timeZoneID: "America/New_York")
    for kind in [HealthKind.heartRate, .restingHeartRate, .hrv] {
        for point in [window.start, now] {
            let active = SampleSource(bundle: "z.synthetic.boundary", family: "Watch", rank: 0)
            let record = HealthRecord(id: "boundary", kind: kind, start: point.addingTimeInterval(-300), end: point, value: 60, source: active)
            let stale = retiredQuantity(kind, at: window.start.addingTimeInterval(-1))
            var future = record; future.id = "future"; future.start = now.addingTimeInterval(1); future.end = future.start; future.source = retiredSource
            var manual = stale; manual.id = "manual"; manual.start = now; manual.end = now; manual.manual = true
            let normalized = RecordNormalizer.normalize([stale, record, future, manual], asOf: now)
            let selected = RecordNormalizer.selected(normalized, kind: kind, profile: profile, sourceWindow: window)
            #expect(selected == [record])
        }
    }
}

// TC-SOURCE-005: a real input is not an excuse to invent a calibrated score.
@Test func activeSourceKeepsMissingAndCalibrationHonest_TC_SOURCE_005() throws {
    let now = DemoData.previewDate, profile = HealthProfile(timeZoneID: "UTC")
    let stale = retiredQuantity(.heartRate, at: now.addingTimeInterval(-90 * 86400))
    let missing = try HealthEngine.evaluate(records: [stale], profile: profile, asOf: now, inputRevision: 1)
    #expect(missing.stressTimeline.isEmpty)
    #expect(missing.stress.reasons.contains("missingHR"))
    let time = now.addingTimeInterval(-300)
    let current = HealthRecord(id: "current", kind: .heartRate, start: time, end: time, value: 70,
                               source: SampleSource(bundle: "z.synthetic.current", family: "Watch", rank: 0))
    let calibrating = try HealthEngine.evaluate(records: [stale, current], profile: profile, asOf: now, inputRevision: 2)
    #expect(!calibrating.stressTimeline.isEmpty)
    #expect(calibrating.stress.availability == .calibrating)
    #expect(calibrating.stress.value == nil)
    #expect(calibrating.energy.estimate.value == nil)
}

// TC-SOURCE-006: migrate a synthetic pre-fix cache via the real repository path.
@Test func activeSourceRebuildAdvancesEpochAndSnapshot_TC_SOURCE_006() async throws {
    let now = DemoData.previewDate
    let profile = HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190)
    let records = try DemoData.records(asOf: now)
    let stale = retiredQuantity(.heartRate, at: now.addingTimeInterval(-90 * 86400))
    var expected = try HealthEngine.evaluate(records: records, profile: profile, asOf: now, inputRevision: 10)
    var legacyReport = expected
    legacyReport.sourceSignature = [retiredSource.group, "wristlab.synthetic/Watch", "wristlab.synthetic/Watch", "wristlab.synthetic/Watch"].joined(separator: "|")
    legacyReport.stress = MetricEstimate(reasons: ["missingHR"])
    legacyReport.stressTimeline = []
    legacyReport.energy = EnergyReport(estimate: MetricEstimate(reasons: ["recalibrationRequired"]), points: [])
    var state = RepositoryState(profile: profile)
    state.producerID = "synthetic-source-transition"; state.epoch = 3; state.sequence = 7
    state.revision = 9; state.records = records + [stale]; state.readingEnabled = true
    state.report = legacyReport
    state.snapshot = DisplaySnapshot(report: legacyReport, producerID: state.producerID, epoch: 3, sequence: 7)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("synthetic-state.json")
    try JSONEncoder().encode(state).write(to: file)
    let repository = try HealthRepository(file: file)
    let revised = try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: 9)
    #expect(revised.epoch == 4)
    #expect(revised.sequence == 0)
    #expect(revised.report == expected)
    let expectedSnapshot = DisplaySnapshot(report: expected, producerID: state.producerID, epoch: 4, sequence: 0)
    #expect(revised.snapshot == expectedSnapshot)
    try revised.snapshot?.validate()
    let reopened = try HealthRepository(file: file)
    #expect(await reopened.current().snapshot == revised.snapshot)
    expected.inputRevision = 11
    let duplicate = try await repository.apply(RecordBatch(additions: []), asOf: now, expectedRevision: 10)
    #expect(duplicate.epoch == revised.epoch)
    #expect(duplicate.snapshot == revised.snapshot)
    #expect(duplicate.report == expected)
}

// TC-SOURCE-004: lock the engine's analysis timezone and calendar-day cutoff.
@Test func activeSourceEngineUsesCalendarWindowAcrossDST_TC_SOURCE_004() throws {
    let now = date("2026-11-02T14:00:00Z")
    let clock = try AnalysisClock(timeZoneID: "America/New_York")
    let cutoff = clock.shiftedDay(now, by: -60)
    let boundarySource = SampleSource(bundle: "b.synthetic.boundary", family: "Watch", rank: 0)
    let currentSource = SampleSource(bundle: "z.synthetic.current", family: "Watch", rank: 0)
    let records = [
        retiredQuantity(.heartRate, at: cutoff.addingTimeInterval(-1)),
        HealthRecord(id: "boundary", kind: .heartRate, start: cutoff.addingTimeInterval(-300), end: cutoff, value: 70, source: boundarySource),
        HealthRecord(id: "current", kind: .heartRate, start: now.addingTimeInterval(-300), end: now.addingTimeInterval(-300), value: 70, source: currentSource)
    ]
    let report = try HealthEngine.evaluate(records: records, profile: HealthProfile(timeZoneID: "America/New_York"), asOf: now, inputRevision: 1)
    #expect(report.sourceSignature == boundarySource.group)
}
