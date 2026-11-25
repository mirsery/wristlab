import Foundation
import Testing
import WristlabCore
@testable import SnapshotStorage

struct WatchDisplayStoreTests {
    @Test func careProjectionIsAtomicBoundedAndMoodFree_TC_WCS_004() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("display.json")
        let store = try WatchDisplayStore(file: file, phone: nil)
        let legacy = Data("{\"schemaVersion\":1,\"localState\":\"notConnected\",\"cleanupPending\":false,\"generation\":0}".utf8)
        #expect(try WatchDisplayEnvelope.decode(legacy).careProjection == nil)
        let now = Date(timeIntervalSince1970: 1_792_483_200)
        let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
        let daily = DailyActivityReport(timeZoneID: "UTC", day: day, steps: [DaySteps(day: day, count: 12)], stepsReadAt: now)
        let next = try store.envelope.updatingCare(WatchCareProjection(daily: daily))
        let before = try Data(contentsOf: file)
        #expect(throws: (any Error).self) { try store.commit(next, persist: { _ in throw DomainError.invalidSnapshot }) }
        #expect(try Data(contentsOf: file) == before)
        #expect(store.envelope.careProjection == nil)
        try store.commit(next)
        let data = try Data(contentsOf: file)
        #expect(!String(decoding: data, as: UTF8.self).contains("mood"))
        #expect(try WatchDisplayStore(file: file, phone: nil).envelope.careProjection?.daily == daily)
        let atLimit = data + Data(repeating: 32, count: 40000 - data.count)
        #expect(try WatchDisplayEnvelope.decode(atLimit).careProjection?.daily == daily)
        #expect(throws: (any Error).self) { try WatchDisplayEnvelope.decode(atLimit + Data([32])) }
        try store.commit(next.stoppingLocal())
        let stopped = try WatchDisplayStore(file: file, phone: nil).envelope
        #expect(stopped.cleanupPending && stopped.careProjection == nil)
        #expect(throws: (any Error).self) { try stopped.updatingCare(WatchCareProjection(daily: daily)) }
    }
    @Test func failedProjectionKeepsCommittedSelection_TC_WSOURCE_003() throws {
        enum Failure: Error { case write }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("display.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try WatchDisplayStore(file: file, phone: nil)
        let initial = store.envelope
        let next = try initial.selecting(.local, snapshot: nil)
        #expect(throws: Failure.self) { try store.commit(next, persist: { _ in throw Failure.write }) }
        #expect(store.envelope == initial)
        try store.commit(next)
        #expect(try WatchDisplayStore(file: file, phone: nil).envelope == next)
    }
    @Test func corruptedDisplayNeverFallsBackToPhone_TC_WSOURCE_005() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("display.json")
        try Data("broken".utf8).write(to: file)
        var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic", epoch: 1, sequence: 1)
        phone.source = .healthKit
        #expect(throws: (any Error).self) { try WatchDisplayStore(file: file, phone: phone) }
        #expect(try Data(contentsOf: file) == Data("broken".utf8))
    }
}
