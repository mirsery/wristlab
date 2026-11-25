import Foundation
import Testing
import WristlabCore

@Suite(.serialized) @MainActor struct PhoneHealthConnectionTests {
    private func withModel(_ body: (DashboardModel, HealthKitReader, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-phone-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("health-state.json")
        let reader = HealthKitReader()
        let model = DashboardModel(reader: reader, repositoryFile: file, clearNotifications: {})
        model.morningBriefEnabled = false
        model.moodConnected = false
        try await body(model, reader, file)
    }
    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw SyntheticPhoneFailure.query
    }
    @Test func authorizationFeedbackAndDuplicate_TC_PHC_001() async throws {
        try await withModel { model, reader, _ in
            reader.holdAuthorization = true
            let previous = model.status
            let first = Task { await model.connect() }
            try await waitFor { !reader.authorizationWaiters.isEmpty }
            #expect(model.busy)
            #expect(model.status != previous)
            let second = Task { await model.connect() }
            for _ in 0..<30 { await Task.yield() }
            #expect(reader.authorizations == 1)
            reader.holdAuthorization = false
            reader.releaseAuthorization()
            await first.value
            await second.value
            #expect(reader.reads == 1)
            #expect(!model.busy)
        }
    }
    @Test func callerCancellationDoesNotAbort_TC_PHC_002() async throws {
        try await withModel { model, reader, _ in
            let caller = Task { await model.refresh(force: true) }
            caller.cancel()
            let outcome = await caller.value
            #expect(outcome != .failed)
            #expect(model.status != "刷新已取消")
            #expect(reader.reads == 1)
            #expect(model.report != nil)
            #expect(!model.busy)
        }
    }
    @Test func concurrentJoinAndForcedConnection_TC_PHC_003() async throws {
        try await withModel { model, reader, _ in
            reader.holdReads = true
            let first = Task { await model.refresh(force: true) }
            try await waitFor { !reader.readWaiters.isEmpty }
            let second = Task { await model.refresh() }
            let connection = Task { await model.connect() }
            for _ in 0..<30 { await Task.yield() }
            #expect(reader.reads == 1)
            reader.holdReads = false
            reader.releaseReads()
            _ = await first.value
            _ = await second.value
            await connection.value
            #expect(reader.authorizations == 1)
            #expect(reader.reads == 2)
            #expect(!model.busy)
        }
    }
    @Test func runningCallerCancellationDoesNotAbort_TC_PHC_002() async throws {
        try await withModel { model, reader, _ in
            reader.holdReads = true
            let caller = Task { await model.refresh(force: true) }
            try await waitFor { !reader.readWaiters.isEmpty }
            caller.cancel()
            reader.holdReads = false
            reader.releaseReads()
            #expect(await caller.value != .failed)
            #expect(model.report != nil)
            #expect(!model.busy)
        }
    }
    @Test func workoutRebuildIsNotLost_TC_PHC_003() async throws {
        try await withModel { model, reader, _ in
            await model.connect()
            reader.holdReads = true
            let first = Task { await model.refresh() }
            try await waitFor { !reader.readWaiters.isEmpty }
            let rebuild = Task { await model.refresh(rebuildingWorkouts: true) }
            for _ in 0..<30 { await Task.yield() }
            reader.holdReads = false
            reader.releaseReads()
            _ = await first.value
            _ = await rebuild.value
            #expect(reader.reads == 3)
            #expect(reader.inputAnchors.last?.isEmpty == true)
        }
    }
    @Test func observerUpdatesAreBounded_TC_PHC_003() async throws {
        try await withModel { model, reader, _ in
            await model.connect()
            reader.holdReads = true
            let first = Task { await model.refresh() }
            try await waitFor { !reader.readWaiters.isEmpty }
            let observers = (0..<6).map { _ in Task { await reader.observer?() } }
            for _ in 0..<30 { await Task.yield() }
            reader.holdReads = false
            reader.releaseReads()
            _ = await first.value
            for observer in observers { await observer.value }
            #expect(reader.reads == 3)
            #expect(!model.busy)
        }
    }
    @Test func corruptCacheHasFeedbackAndRetry_TC_PHC_004() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-corrupt-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("health-state.json")
        let original = Data("synthetic-corrupt-cache".utf8)
        try original.write(to: file)
        let reader = HealthKitReader()
        let model = DashboardModel(reader: reader, repositoryFile: file)
        model.morningBriefEnabled = false
        let before = model.status
        await model.connect()
        #expect(model.status != before)
        #expect(try Data(contentsOf: file) == original)
        #expect(reader.authorizations == 0)
        #expect(!model.busy)
        try FileManager.default.removeItem(at: file)
        await model.connect()
        #expect(reader.authorizations == 1)
        #expect(model.report != nil)
    }
    @Test func failedReadDoesNotLoopObserverRetry_TC_PHC_003() async throws {
        try await withModel { model, reader, _ in
            await model.connect()
            reader.holdReads = true
            let first = Task { await model.refresh() }
            try await waitFor { !reader.readWaiters.isEmpty }
            let observer = Task { await reader.observer?() }
            for _ in 0..<30 { await Task.yield() }
            reader.queryFailure = true
            reader.releaseReads()
            #expect(await first.value == .failed)
            await observer.value
            for _ in 0..<30 { await Task.yield() }
            #expect(reader.reads == 2)
            #expect(!model.busy)
        }
    }
    @Test func stoppedAuthorizationCannotStartReading_TC_PHC_005() async throws {
        try await withModel { model, reader, file in
            reader.holdAuthorization = true
            let connection = Task { await model.connect() }
            try await waitFor { !reader.authorizationWaiters.isEmpty }
            await model.clear(stop: true)
            reader.releaseAuthorization()
            await connection.value
            #expect(reader.reads == 0)
            #expect(model.report == nil)
            #expect(!model.busy)
            let stopped = try HealthRepository(file: file)
            #expect(!(await stopped.current()).readingEnabled)
        }
    }
    @Test func stopRejectsLateRead_TC_PHC_005() async throws {
        try await withModel { model, reader, file in
            reader.holdReads = true
            reader.ignoreCancellation = true
            var record = HealthRecord(id: "synthetic-late-stop", kind: .heartRate,
                start: Date().addingTimeInterval(-60), end: Date().addingTimeInterval(-60),
                source: SampleSource(bundle: "synthetic.watch", family: "Watch", rank: 0))
            record.value = 75
            reader.records = [record]
            let first = Task { await model.refresh(force: true) }
            try await waitFor { !reader.readWaiters.isEmpty }
            await model.clear(stop: true)
            let stoppedStatus = model.status
            reader.releaseReads()
            _ = await first.value
            let stopped = try HealthRepository(file: file)
            #expect(!(await stopped.current()).readingEnabled)
            #expect((await stopped.current()).records.isEmpty)
            #expect((await stopped.current()).anchors.isEmpty)
            #expect((await stopped.current()).report == nil)
            #expect(model.status == stoppedStatus)
            #expect(model.report == nil)
            #expect(!model.busy)
            let outcome = await model.refresh()
            #expect(outcome == .needsHealthConnection)
            #expect(reader.reads == 1)
            #expect(reader.cancellations > 0)
        }
    }
    @Test func clearCancelsAndRejectsLateRead_TC_PHC_005() async throws {
        try await withModel { model, reader, file in
            reader.holdReads = true
            reader.ignoreCancellation = true
            var record = HealthRecord(id: "synthetic-late-clear", kind: .heartRate,
                start: Date().addingTimeInterval(-60), end: Date().addingTimeInterval(-60),
                source: SampleSource(bundle: "synthetic.watch", family: "Watch", rank: 0))
            record.value = 80
            reader.records = [record]
            let first = Task { await model.refresh(force: true) }
            try await waitFor { !reader.readWaiters.isEmpty }
            await model.clear(stop: false)
            reader.releaseReads()
            _ = await first.value
            #expect(reader.cancellations > 0)
            let cleared = try HealthRepository(file: file)
            #expect((await cleared.current()).records.isEmpty)
            #expect((await cleared.current()).anchors.isEmpty)
            #expect((await cleared.current()).report == nil)
            #expect(model.report == nil)
            #expect(!model.busy)
        }
    }
    @Test func authorizationFailureCanRetry_TC_PHC_006() async throws {
        try await withModel { model, reader, _ in
            reader.authorizationFailure = true
            await model.connect()
            #expect(!model.busy)
            #expect(model.status.contains("无法"))
            reader.authorizationFailure = false
            await model.connect()
            #expect(reader.authorizations == 2)
            #expect(model.report != nil)
        }
    }
    @Test func readFailurePreservesCacheAndPlanning_TC_PHC_006() async throws {
        try await withModel { model, reader, file in
            let now = Date()
            var planning = PlanningState()
            planning.weights = [WeightEntry(id: "synthetic-weight", kilograms: 60, at: now, recordedAt: now)]
            await model.connect()
            let saved = await model.updatePlanning { $0 = planning }
            #expect(saved)
            let before = try Data(contentsOf: file)
            let previousReport = model.report
            reader.queryFailure = true
            _ = await model.refresh()
            #expect(!model.busy)
            #expect(model.report == previousReport)
            #expect(try Data(contentsOf: file) == before)
            #expect(model.planning == planning)
            reader.queryFailure = false
            _ = await model.refresh()
            #expect(model.status.contains("暂无"))
            #expect(model.planning == planning)
        }
    }
    @Test func emptyReadDoesNotClaimDenial_TC_PHC_006() async throws {
        try await withModel { model, _, _ in
            await model.connect()
            #expect(model.status.contains("暂无"))
            #expect(!model.status.contains("拒绝"))
            #expect(model.report?.readiness.value == nil)
            #expect(!model.busy)
        }
    }
}
