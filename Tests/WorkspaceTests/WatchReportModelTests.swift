import Foundation
import Testing
import WristlabCore
import SnapshotStorage
@testable import WatchSupport

@MainActor private final class SyntheticWatchReader: WatchHealthReading {
    var authorizations = 0
    var authorizationFailure = false
    var reads = 0
    var cancelled = false
    var failure = false
    var suspended = false
    var records: [HealthRecord] = []
    var continuation: CheckedContinuation<RecordBatch, any Error>?
    func authorize() async throws {
        authorizations += 1
        if authorizationFailure { throw DomainError.invalidSnapshot }
    }
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        reads += 1
        if failure { throw DomainError.invalidSnapshot }
        if suspended {
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        return RecordBatch(additions: records, anchors: [:])
    }
    func cancel() { cancelled = true }
}

@MainActor struct WatchReportModelTests {
    @Test func careClearFailureAndRestartKeepBarrier_TC_WCS_005() async throws {
        try await withModel { model, reader, repository, display in
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("care.json")
            defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            let careStore = try CareStateStore(file: file)
            let now = Date()
            let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
            var state = CareState()
            state.activityEnabled = true
            state.daily = DailyActivityReport(timeZoneID: "UTC", day: day, steps: [DaySteps(day: day, count: 123)], stepsReadAt: now)
            state.mood = try CareMoodRecord(mood: .calm, at: now, timeZoneID: "UTC")
            try careStore.save(state)
            await model.connectLocal()
            try model.updateActivity(state.daily)
            var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-phone", epoch: 0, sequence: 1)
            phone.source = .healthKit
            phone.clearData = true
            phone.readiness = MetricEstimate(); phone.energy = MetricEstimate(); phone.stress = MetricEstimate()
            phone.exertion = MetricEstimate(); phone.sleepMinutes = nil
            model.receivePhone(phone)
            #expect(careStore.state.mood?.mood == .calm)
            #expect(model.envelope?.careProjection?.daily == state.daily)
            model.onClearLocal = { throw DomainError.invalidSnapshot }
            await model.stopLocal()
            #expect(display.envelope.cleanupPending && display.envelope.careProjection == nil)
            #expect(careStore.state.mood != nil)
            #expect(throws: (any Error).self) { try model.updateActivity(state.daily) }
            let reopened = WatchReportModel(reader: reader, repository: repository, store: display, phone: nil)
            reopened.onClearLocal = { try careStore.save(CareState()) }
            let reads = reader.reads
            await reopened.start()
            #expect(reopened.envelope?.cleanupPending == false)
            #expect(reopened.envelope?.careProjection == nil)
            #expect(try CareStateStore(file: file).state == CareState())
            #expect(reader.reads == reads)
            #expect(!(await repository.current().readingEnabled))
        }
    }
    @Test func sourceSwitchKeepsConcurrentActivity_TC_WCS_004() async throws {
        try await withModel { model, _, _, _ in
            await model.select(.phone)
            let now = Date()
            let day = try AnalysisClock(timeZoneID: "UTC").day(containing: now).start
            let daily = DailyActivityReport(timeZoneID: "UTC", day: day, steps: [DaySteps(day: day, count: 777)], stepsReadAt: now)
            let switchTask = Task { @MainActor in await model.select(.phone) }
            let activityTask = Task { @MainActor in try model.updateActivity(daily) }
            try await activityTask.value
            await switchTask.value
            #expect(model.envelope?.careProjection?.daily == daily)
        }
    }
    private func withModel(_ test: @MainActor (WatchReportModel, SyntheticWatchReader, HealthRepository, WatchDisplayStore) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HealthRepository(file: directory.appendingPathComponent("local.json"))
        let store = try WatchDisplayStore(file: directory.appendingPathComponent("display.json"), phone: nil)
        let reader = SyntheticWatchReader()
        let model = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil)
        try await test(model, reader, repository, store)
    }
    @Test func passiveStartDoesNotReadAndIndependentConnectWorks_TC_WLOCAL_001() async throws {
        try await withModel { model, reader, repository, _ in
            await model.start()
            #expect(reader.authorizations == 0 && reader.reads == 0)
            await model.connectLocal()
            #expect(reader.authorizations == 1 && reader.reads == 1)
            #expect(model.envelope?.mode == .local)
            #expect(model.snapshot?.source == .healthKit)
            #expect(await repository.current().readingEnabled)
        }
    }
    @Test func localSettingsAreIndependentAndValidated_TC_WLOCAL_003() async throws {
        try await withModel { model, reader, repository, _ in
            await model.start()
            var profile = model.profile
            #expect(profile.maximumHeartRate == nil)
            #expect(profile.sleepTargetMinutes == 480)
            profile.sleepTargetMinutes = 450
            await model.configure(profile)
            #expect(await repository.current().profile.sleepTargetMinutes == 450)
            #expect(reader.reads == 0)
            profile.sleepTargetMinutes = 1
            await model.configure(profile)
            #expect(await repository.current().profile.sleepTargetMinutes == 450)
        }
    }
    @Test func clearWinsOverLateReadAndRequiresReconnect_TC_WLOCAL_004() async throws {
        try await withModel { model, reader, repository, store in
            await model.connectLocal()
            reader.suspended = true
            let task = Task { await model.refreshLocal() }
            while reader.continuation == nil { await Task.yield() }
            await model.stopLocal()
            reader.continuation?.resume(returning: RecordBatch(additions: [], anchors: [:]))
            reader.continuation = nil
            await task.value
            #expect(reader.cancelled)
            #expect(model.envelope?.localState == .stopped)
            #expect(model.snapshot == nil)
            #expect(!(await repository.current().readingEnabled))
            let restarted = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil)
            let reads = reader.reads
            await restarted.start()
            #expect(reader.reads == reads)
        }
    }
    @Test func readFailurePreservesSnapshotAndRevision_TC_WLOCAL_005() async throws {
        try await withModel { model, reader, repository, _ in
            await model.connectLocal()
            let snapshot = model.snapshot
            let revision = await repository.current().revision
            reader.failure = true
            await model.refreshLocal()
            #expect(model.snapshot == snapshot)
            #expect(await repository.current().revision == revision)
            #expect(model.notice != nil)
        }
    }
    @Test func phoneReceptionAndModeSwitchDoNotMix_TC_WSOURCE_002() async throws {
        try await withModel { model, _, _, _ in
            await model.connectLocal()
            let local = model.snapshot
            var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-phone", epoch: 1, sequence: 1)
            phone.source = .healthKit
            model.receivePhone(phone)
            #expect(model.snapshot == local)
            await model.select(.phone)
            #expect(model.snapshot == phone)
            await model.select(.local)
            #expect(model.snapshot == local)
        }
    }
    @Test func watchUsesSameEngineAndClock_TC_WLOCAL_002() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let profile = HealthProfile(timeZoneID: "UTC", maximumHeartRate: 185)
        let repository = try HealthRepository(file: directory.appendingPathComponent("local.json"), profile: profile)
        let store = try WatchDisplayStore(file: directory.appendingPathComponent("display.json"), phone: nil)
        let reader = SyntheticWatchReader()
        reader.records = try DemoData.records(asOf: DemoData.previewDate)
        let model = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil, now: { DemoData.previewDate })
        await model.connectLocal()
        let state = await repository.current()
        let expected = try HealthEngine.evaluate(records: reader.records, profile: profile, asOf: DemoData.previewDate, inputRevision: state.revision)
        let expectedSnapshot = DisplaySnapshot(report: expected, producerID: state.producerID, epoch: state.epoch, sequence: state.sequence)
        #expect(model.snapshot?.readiness == expectedSnapshot.readiness)
        #expect(model.snapshot?.stress == expectedSnapshot.stress)
        #expect(model.snapshot?.energy == expectedSnapshot.energy)
        #expect(model.snapshot?.exertion == expectedSnapshot.exertion)
        #expect(model.snapshot?.sleepMinutes == expectedSnapshot.sleepMinutes)
        #expect(model.snapshot?.computedAt == DemoData.previewDate)
    }
    @Test func stopMarkerFailureDoesNotClaimDeletion_TC_WLOCAL_004() async throws {
        enum Failure: Error { case write }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HealthRepository(file: directory.appendingPathComponent("local.json"))
        var fail = false
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try WatchDisplayStore(file: directory.appendingPathComponent("display.json"), phone: nil, writer: { data, file in
            if fail { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let model = WatchReportModel(reader: SyntheticWatchReader(), repository: repository, store: store, phone: nil)
        await model.connectLocal()
        fail = true
        await model.stopLocal()
        #expect(model.envelope?.localState == .enabled)
        #expect(model.notice?.contains("清除未完成") == true)
        #expect(await repository.current().readingEnabled)
    }
    @Test func cleanupFailureRemainsStoppedAcrossRestart_TC_WLOCAL_004() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("local.json")
        let repository = try HealthRepository(file: file)
        let store = try WatchDisplayStore(file: directory.appendingPathComponent("display.json"), phone: nil)
        let reader = SyntheticWatchReader()
        let model = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil)
        reader.records = Array(try DemoData.records(asOf: DemoData.previewDate).prefix(2))
        await model.connectLocal()
        let saved = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        await model.stopLocal()
        #expect(store.envelope.cleanupPending)
        #expect(model.snapshot == nil)
        try FileManager.default.removeItem(at: file)
        try saved.write(to: file)
        let reopenedRepository = try HealthRepository(file: file)
        let reopenedStore = try WatchDisplayStore(file: directory.appendingPathComponent("display.json"), phone: nil)
        #expect(await reopenedRepository.current().readingEnabled)
        #expect(reopenedStore.envelope.cleanupPending)
        let restarted = WatchReportModel(reader: reader, repository: reopenedRepository, store: reopenedStore, phone: nil)
        let reads = reader.reads
        await restarted.start()
        #expect(reader.reads == reads)
        #expect(restarted.envelope?.localState == .stopped)
        #expect(restarted.snapshot == nil)
        #expect(!(await reopenedRepository.current().readingEnabled))
        #expect(await reopenedRepository.current().records.isEmpty)
    }
    @Test func modeSwitchDiscardsLateLocalRead_TC_WSOURCE_002() async throws {
        try await withModel { model, reader, repository, _ in
            await model.connectLocal()
            let revision = await repository.current().revision
            reader.suspended = true
            let task = Task { await model.refreshLocal() }
            while reader.continuation == nil { await Task.yield() }
            await model.select(.phone)
            reader.continuation?.resume(returning: RecordBatch(additions: [], anchors: [:]))
            reader.continuation = nil
            await task.value
            #expect(model.envelope?.mode == .phone)
            #expect(await repository.current().revision == revision)
        }
    }
    @Test func foregroundRefreshesOnlyEnabledRealLocalMode_TC_WLOCAL_001() async throws {
        try await withModel { model, reader, _, _ in
            await model.start()
            await model.connectLocal()
            let initial = reader.reads
            await model.foreground()
            #expect(reader.reads == initial + 1)
            await model.setDemo(true)
            await model.foreground()
            #expect(reader.reads == initial + 1)
            await model.setDemo(false)
            await model.stopLocal()
            let stopped = reader.reads
            await model.foreground()
            #expect(reader.reads == stopped)
        }
    }
    @Test func clearedPhoneProjectionRetriesOnDiskRestart_TC_WSOURCE_004() async throws {
        enum Failure: Error { case write }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("display.json")
        var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic", epoch: 1, sequence: 1)
        phone.source = .healthKit
        var fail = false
        let store = try WatchDisplayStore(file: file, phone: phone, writer: { data, file in
            if fail { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let repositoryFile = directory.appendingPathComponent("local.json")
        let model = WatchReportModel(reader: SyntheticWatchReader(), repository: try HealthRepository(file: repositoryFile), store: store, phone: phone)
        var receiver = SnapshotReceiver()
        try receiver.accept(phone, confirmProducer: true)
        phone.epoch = 2; phone.sequence = 0; phone.clearData = true
        phone.readiness = MetricEstimate(); phone.stress = MetricEstimate()
        phone.energy = MetricEstimate(); phone.exertion = MetricEstimate(); phone.sleepMinutes = nil
        try receiver.accept(phone)
        let phoneFile = directory.appendingPathComponent("phone.json")
        try JSONEncoder().encode(receiver).write(to: phoneFile)
        fail = true
        model.receivePhone(phone)
        #expect(model.snapshot?.clearData == false)
        let restoredPhone = try JSONDecoder().decode(SnapshotReceiver.self, from: Data(contentsOf: phoneFile)).snapshot
        let restarted = WatchReportModel(reader: SyntheticWatchReader(), repository: try HealthRepository(file: repositoryFile),
            store: try WatchDisplayStore(file: file, phone: restoredPhone), phone: restoredPhone)
        await restarted.start()
        #expect(restarted.snapshot?.clearData == true)
        #expect(try WatchDisplayStore(file: file, phone: nil).envelope.snapshot?.clearData == true)
    }
    @Test func repositorySuccessProjectionFailureRetriesAndModeFailureKeepsSelection_TC_WSOURCE_003() async throws {
        enum Failure: Error { case write }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("display.json")
        var failing = false
        var writes = 0
        let store = try WatchDisplayStore(file: file, phone: nil, writer: { data, file in
            if failing { writes += 1; if writes >= 2 { throw Failure.write } }
            try data.write(to: file, options: .atomic)
        })
        let repository = try HealthRepository(file: directory.appendingPathComponent("local.json"))
        let reader = SyntheticWatchReader()
        var now = DemoData.previewDate
        let model = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil, now: { now })
        await model.connectLocal()
        let previous = model.snapshot
        failing = true
        reader.records = try DemoData.records(asOf: DemoData.previewDate)
        now = now.addingTimeInterval(60)
        await model.refreshLocal()
        #expect(model.snapshot == previous)
        #expect(model.notice != nil)
        let committed = await repository.current().snapshot
        #expect(committed?.computedAt != previous?.computedAt)
        await model.select(.phone)
        #expect(model.envelope?.mode == .local)
        #expect(try WatchDisplayStore(file: file, phone: nil).envelope.mode == .local)
        failing = false
        reader.failure = true
        await model.refreshLocal()
        #expect(model.snapshot == committed)
    }
    @Test func failedReadAndAuthorizationHaveTerminalStatuses_TC_WLOCAL_005() async throws {
        try await withModel { model, reader, _, _ in
            await model.connectLocal()
            let previous = model.snapshot
            reader.failure = true
            await model.refreshLocal()
            #expect(!model.busy)
            #expect(!model.status.hasPrefix("正在"))
            #expect(model.notice != nil)
            #expect(model.snapshot == previous)
            reader.failure = false
            await model.refreshLocal()
            #expect(model.notice == nil)
            reader.authorizationFailure = true
            await model.connectLocal()
            #expect(!model.busy)
            #expect(!model.status.hasPrefix("正在"))
            #expect(model.notice != nil)
        }
    }
    @Test func configureProjectionFailurePreservesDisplayAndCanRetry_TC_WSOURCE_003() async throws {
        enum Failure: Error { case write }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("display.json")
        var failing = false
        let store = try WatchDisplayStore(file: file, phone: nil, writer: { data, file in
            if failing { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let repository = try HealthRepository(file: folder.appendingPathComponent("local.json"))
        let reader = SyntheticWatchReader()
        let model = WatchReportModel(reader: reader, repository: repository, store: store, phone: nil)
        await model.connectLocal()
        let previous = model.snapshot
        let initialReads = reader.reads
        var profile = model.profile
        profile.sleepTargetMinutes = 450
        failing = true
        await model.configure(profile)
        #expect(await repository.current().profile.sleepTargetMinutes == 450)
        #expect(model.profile.sleepTargetMinutes == 450)
        #expect(model.snapshot == previous)
        #expect(try WatchDisplayStore(file: file, phone: nil).envelope.snapshot == previous)
        #expect(model.notice != nil)
        #expect(!model.busy)
        #expect(reader.reads == initialReads)
        failing = false
        await model.configure(profile)
        #expect(model.notice == nil)
        #expect(model.snapshot == (await repository.current().snapshot))
    }
    @Test func phoneProjectionRetryClearsObsoleteError_TC_WSOURCE_003() async throws {
        enum Failure: Error { case write }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var failing = false
        var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-retry", epoch: 1, sequence: 1)
        phone.source = .healthKit
        let store = try WatchDisplayStore(file: folder.appendingPathComponent("display.json"), phone: phone, writer: { data, file in
            if failing { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let model = WatchReportModel(reader: SyntheticWatchReader(), repository: try HealthRepository(file: folder.appendingPathComponent("local.json")), store: store, phone: phone)
        await model.start()
        phone.sequence = 2
        failing = true
        model.receivePhone(phone)
        #expect(model.notice != nil)
        #expect(model.snapshot?.sequence == 1)
        failing = false
        model.receivePhone(phone)
        #expect(model.snapshot?.sequence == 2)
        #expect(model.notice == nil)
        #expect(!model.status.hasPrefix("正在"))
    }
    @Test func phoneSuccessPreservesPendingCleanupNotice_TC_WLOCAL_004() async throws {
        enum Failure: Error { case write }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("local.json")
        let repository = try HealthRepository(file: file)
        var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-pending", epoch: 1, sequence: 1)
        phone.source = .healthKit
        var failingDisplay = false
        let store = try WatchDisplayStore(file: folder.appendingPathComponent("display.json"), phone: phone, writer: { data, file in
            if failingDisplay { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let model = WatchReportModel(reader: SyntheticWatchReader(), repository: repository, store: store, phone: phone)
        await model.connectLocal()
        await model.select(.phone)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        await model.stopLocal()
        #expect(model.envelope?.cleanupPending == true)
        #expect(model.notice?.contains("清理未完成") == true)
        phone.sequence = 2
        model.receivePhone(phone)
        #expect(model.snapshot?.sequence == 2)
        #expect(model.envelope?.cleanupPending == true)
        #expect(model.notice?.contains("清理未完成") == true)
        #expect(model.status.contains("清理"))
        await model.select(.local)
        phone.clearData = true
        phone.readiness = MetricEstimate(); phone.stress = MetricEstimate()
        phone.energy = MetricEstimate(); phone.exertion = MetricEstimate(); phone.sleepMinutes = nil
        model.receivePhone(phone)
        #expect(model.notice?.contains("清理未完成") == true)
        #expect(model.status.contains("清理"))
        failingDisplay = true
        await model.select(.phone)
        #expect(model.envelope?.mode == .local)
        #expect(model.notice?.contains("清理未完成") == true)
        await model.stopLocal()
        #expect(model.notice?.contains("清理未完成") == true)
    }
    @Test func phoneSuccessRestoresUnavailableLocalCacheNotice_TC_WSOURCE_003() throws {
        enum Failure: Error { case write }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var phone = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-unavailable", epoch: 1, sequence: 1)
        phone.source = .healthKit
        var failing = false
        let store = try WatchDisplayStore(file: folder.appendingPathComponent("display.json"), phone: phone, writer: { data, file in
            if failing { throw Failure.write }
            try data.write(to: file, options: .atomic)
        })
        let model = WatchReportModel(reader: SyntheticWatchReader(), repository: nil, store: store, phone: phone)
        failing = true
        phone.sequence = 2
        model.receivePhone(phone)
        #expect(model.notice?.contains("本地缓存不可读取") == true)
        failing = false
        model.receivePhone(phone)
        #expect(model.snapshot?.sequence == 2)
        #expect(model.notice?.contains("本地缓存不可读取") == true)
        #expect(model.notice?.contains("展示缓存更新失败") != true)
    }
}
