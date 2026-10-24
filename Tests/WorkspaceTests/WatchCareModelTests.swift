import Foundation
import Testing
import WristlabCore
import SnapshotStorage
@testable import WatchSupport

@MainActor private final class SyntheticActivityReader: DailyActivityReading {
    var authorizations = 0
    var reads = 0
    var continuation: CheckedContinuation<DailyActivityReport, any Error>?
    var suspend = false
    var nextResult: DailyActivityReport?
    func authorize() async throws { authorizations += 1 }
    func cancel() {}
    func read(at now: Date, timeZoneID: String) async throws -> DailyActivityReport {
        reads += 1
        if suspend { return try await withCheckedThrowingContinuation { continuation = $0 } }
        if let nextResult { return nextResult }
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        return DailyActivityReport(timeZoneID: timeZoneID, day: clock.day(containing: now).start,
            steps: [DaySteps(day: clock.day(containing: now).start, count: 0)], stepsReadAt: now)
    }
}
@MainActor struct WatchCareModelTests {
    @Test func explicitActivityAndStopLateRead_TC_WDA_001_005() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CareStateStore(file: file)
        let reader = SyntheticActivityReader()
        let now = Date(timeIntervalSince1970: 1_792_483_200)
        let model = WatchCareModel(reader: reader, store: store, now: { now }, timeZoneID: { "UTC" })
        var projected: DailyActivityReport?
        model.publishActivity = { projected = $0 }
        await model.foreground()
        #expect(reader.reads == 0 && reader.authorizations == 0)
        await model.connect()
        #expect(reader.reads == 1 && reader.authorizations == 1)
        #expect(projected?.currentSteps(at: now, timeZoneID: "UTC") == 0)
        reader.suspend = true
        let task = Task { await model.refresh() }
        for _ in 0..<100 where reader.continuation == nil { await Task.yield() }
        try model.stopActivity()
        let continuation = try #require(reader.continuation)
        let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
        continuation.resume(returning: DailyActivityReport(timeZoneID: "UTC", day: day,
            steps: [DaySteps(day: day, count: 999)], stepsReadAt: now))
        await task.value
        #expect(!store.state.activityEnabled && projected == nil)
        #expect(!model.busy)
    }
    @Test func moodPrivateAndDayGuard_TC_WCS_002() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CareStateStore(file: file)
        var now = Date(timeIntervalSince1970: 1_792_483_200)
        let model = WatchCareModel(reader: SyntheticActivityReader(), store: store, now: { now }, timeZoneID: { "UTC" })
        let captured = now
        try model.saveMood(.low, capturedAt: captured, capturedZone: "UTC", expectedGeneration: model.generation)
        #expect(model.mood?.mood == .low)
        try model.saveMood(.calm, capturedAt: captured, capturedZone: "UTC", expectedGeneration: model.generation)
        #expect(model.mood?.mood == .calm)
        try model.saveMood(nil, capturedAt: captured, capturedZone: "UTC", expectedGeneration: model.generation)
        #expect(model.mood == nil)
        try model.saveMood(.low, capturedAt: captured, capturedZone: "UTC", expectedGeneration: model.generation)
        let generation = model.generation
        let original = try Data(contentsOf: file)
        model.setDemo(true)
        #expect(throws: (any Error).self) { try model.saveMood(.happy, capturedAt: captured, capturedZone: "UTC", expectedGeneration: generation) }
        #expect(try Data(contentsOf: file) == original)
        model.setDemo(false)
        now = now.addingTimeInterval(86400)
        #expect(model.mood == nil)
        #expect(throws: (any Error).self) { try model.saveMood(.happy, capturedAt: captured, capturedZone: "UTC", expectedGeneration: model.generation) }
        try model.clearAll()
        #expect(try CareStateStore(file: file).state.mood == nil)
    }
    @Test func projectionRetry_TC_WCS_004() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CareStateStore(file: file)
        let model = WatchCareModel(reader: SyntheticActivityReader(), store: store)
        model.publishActivity = { _ in throw DomainError.invalidSnapshot }
        await model.connect()
        #expect(store.state.daily != nil && model.notice != nil)
        model.publishActivity = { _ in }
        await model.foreground()
        #expect(model.notice == nil)
    }
    @Test func stopProjectionRecoveryClearsError_TC_WDA_005() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CareStateStore(file: file)
        let model = WatchCareModel(reader: SyntheticActivityReader(), store: store)
        await model.connect()
        model.publishActivity = { value in if value == nil { throw DomainError.invalidSnapshot } }
        #expect(throws: (any Error).self) { try model.stopActivity() }
        #expect(!store.state.activityEnabled && model.notice != nil)
        model.publishActivity = { _ in }
        await model.foreground()
        #expect(model.notice == nil)
        #expect(!model.status.contains("正在"))
    }
    @Test func partialFailurePreservesOriginalTimestamp_TC_WDA_005() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CareStateStore(file: file)
        let reader = SyntheticActivityReader()
        var now = Date(timeIntervalSince1970: 1_792_483_200)
        let original = now
        let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
        let model = WatchCareModel(reader: reader, store: store, now: { now }, timeZoneID: { "UTC" })
        await model.connect()
        now = now.addingTimeInterval(120)
        let rings = ActivityRings(move: ActivityRing(value: 88, goal: 100, unit: "kcal"),
            exercise: ActivityRing(value: 12, goal: 30, unit: "min"), stand: ActivityRing(value: 3, goal: 8, unit: "h"), paused: false)
        reader.nextResult = DailyActivityReport(timeZoneID: "UTC", day: day, rings: rings, ringsReadAt: now, stepsFailed: true)
        await model.refresh()
        #expect(store.state.daily?.stepsReadAt == original)
        #expect(store.state.daily?.ringsReadAt == now)
        #expect(store.state.daily?.stepsFailed == true)
        #expect(store.state.daily?.steps.first?.count == 0)
        let ringReadAt = now
        now = now.addingTimeInterval(120)
        reader.nextResult = DailyActivityReport(timeZoneID: "UTC", day: day,
            steps: [DaySteps(day: day, count: 25)], stepsReadAt: now, ringsFailed: true)
        await model.refresh()
        #expect(store.state.daily?.steps.first?.count == 25)
        #expect(store.state.daily?.ringsReadAt == ringReadAt)
        #expect(store.state.daily?.rings == rings && store.state.daily?.ringsFailed == true)
    }
    @Test func lateDayAndZoneChangeNeverPublish_TC_WDA_004() async throws {
        for changeZone in [false, true] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            let store = try CareStateStore(file: file)
            let reader = SyntheticActivityReader()
            var now = Date(timeIntervalSince1970: 1_792_483_200)
            var zone = "UTC"
            let model = WatchCareModel(reader: reader, store: store, now: { now }, timeZoneID: { zone })
            var projected: DailyActivityReport?
            model.publishActivity = { projected = $0 }
            await model.connect()
            let original = store.state
            reader.suspend = true
            let task = Task { await model.refresh() }
            for _ in 0..<100 where reader.continuation == nil { await Task.yield() }
            let continuation = try #require(reader.continuation)
            if changeZone { zone = "Asia/Shanghai" } else { now = now.addingTimeInterval(86400) }
            continuation.resume(returning: try #require(original.daily))
            await task.value
            #expect(store.state == original && projected == original.daily)
            #expect(!model.busy && model.status.contains("日期"))
            #expect(projected?.currentSteps(at: now, timeZoneID: zone) == nil)
        }
    }
    @Test func failedPrivateWritePreservesFileAndMood_TC_WCS_002() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("care.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        var fail = false
        let store = try CareStateStore(file: file, writer: { data, destination in
            if fail { throw DomainError.invalidSnapshot }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        })
        var state = CareState()
        state.mood = try CareMoodRecord(mood: .low, at: Date(timeIntervalSince1970: 1_792_483_200), timeZoneID: "UTC")
        try store.save(state)
        let original = try Data(contentsOf: file)
        fail = true
        #expect(throws: (any Error).self) { try store.save(CareState()) }
        #expect(store.state.mood?.mood == .low)
        #expect(try Data(contentsOf: file) == original)
        #expect(try CareStateStore(file: file).state.mood?.mood == .low)
        try Data("invalid-synthetic-cache".utf8).write(to: file)
        #expect(throws: (any Error).self) { try CareStateStore(file: file) }
        #expect(try Data(contentsOf: file) == Data("invalid-synthetic-cache".utf8))
    }
}
