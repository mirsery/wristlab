import Foundation
import Combine
@preconcurrency import UserNotifications
import WristlabCore

@MainActor
final class DashboardModel: ObservableObject {
    @Published var report: HealthReport?
    @Published var demo: HealthReport?
    @Published var profile = HealthProfile()
    @Published var status = "点击连接 Apple 健康，开始读取本地记录。"
    @Published var busy = false
    @Published var demoEnabled = false
    @Published private(set) var planning = PlanningState()
    @Published private(set) var demoPlanning = PlanningState()
    @Published var planningNotice: String?
    @Published private(set) var planningBusy = false
    @Published private(set) var contentResetID = UUID()
    private var planningRevision = 0
    @Published private(set) var workoutRecords: [HealthRecord] = []
    @Published private(set) var demoWorkoutRecords: [HealthRecord] = []
    var displayedWorkoutRecords: [HealthRecord] { demoEnabled ? demoWorkoutRecords : workoutRecords }
    var displayedPlanning: PlanningState { demoEnabled ? demoPlanning : planning }
    var planningNow: Date { demoEnabled ? (demo?.asOf ?? DemoData.previewDate) : Date() }
    var planningTimeZone: String { displayed?.timeZoneID ?? profile.timeZoneID }
    @Published var sources: [HealthKind: [String]] = [:]
    @Published var moods: [MoodEntry] = []
    @Published var demoMoods: [MoodEntry] = []
    @Published var moodConnected = UserDefaults.standard.bool(forKey: "moodReadingRequested")
    @Published var moodStatus: String?
    var displayedMoods: [MoodEntry] { demoEnabled ? demoMoods : moods }
    @Published var morningBriefEnabled = UserDefaults.standard.bool(forKey: "morningBriefEnabled")
    @Published var morningBriefShowsValues = UserDefaults.standard.bool(forKey: "morningBriefShowValues")
    /// Shown in settings: why the brief is off or silently blocked. Not the dashboard status line.
    @Published var morningBriefNotice: String?
    var moodSupported: Bool { if #available(iOS 18.0, *) { true } else { false } }
    let bridge = WatchBridge()
    private let reader: HealthKitReader
    private let repositoryFile: URL
    private let clearNotifications: () -> Void
    private var repository: HealthRepository?
    private var generation = 0
    private var pendingRefresh = false
    private var loadError = false
    private var healthOperation: Task<WatchRefreshOutcome, Never>?
    private var healthOperationID: UUID?
    private var authorizingOperation = false
    private var rebuildingOperation = false
    var displayed: HealthReport? { demoEnabled ? demo : report }
    init(reader: HealthKitReader = HealthKitReader(), repositoryFile: URL? = nil,
         clearNotifications: @escaping () -> Void = {
             UNUserNotificationCenter.current().removeAllDeliveredNotifications()
             UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
         }) {
        self.reader = reader
        self.clearNotifications = clearNotifications
        self.repositoryFile = repositoryFile ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wristlab").appendingPathComponent("health-state.json")
        do { repository = try HealthRepository(file: self.repositoryFile) }
        catch { loadError = true; status = "本地缓存不可读取，请保留文件并重试，未覆盖原数据。" }
        bridge.onPrepareSnapshot = { [weak self] in
            guard let self, let repository = self.repository else { return }
            let token = self.generation
            let state = await repository.current()
            guard token == self.generation, let snapshot = state.snapshot else { return }
            self.publish(snapshot)
        }
        bridge.onRefresh = { [weak self] in
            guard let self, let repository = self.repository else { return .failed }
            let initial = await repository.current()
            guard initial.readingEnabled else { return .needsHealthConnection }
            let outcome = await self.refresh()
            let current = await repository.current()
            guard let snapshot = current.snapshot else { return outcome }
            self.publish(snapshot)
            return .snapshotAvailable
        }
    }
    func restoreObservers() async {
        guard let repository else { return }
        let state = await repository.current()
        if state.readingEnabled { observe() }
    }
    func start() async {
        if repository == nil {
            do { repository = try HealthRepository(file: repositoryFile); loadError = false }
            catch { status = "本地缓存暂不可读取，已保留原文件，请解锁设备后重试。" }
        }
        guard let repository else { return }
        let state = await repository.current(); profile = state.profile; report = state.report
        planning = state.planning ?? PlanningState(); planningRevision = state.revision
        workoutRecords = state.records.filter { $0.kind == .workout }
        if let snapshot = state.snapshot { publish(snapshot) }
        updateSources(state)
        if ProcessInfo.processInfo.arguments.contains("--demo") { await enableDemo(); return }
        if state.readingEnabled { observe(); await refresh() }
    }
    func connect() async {
        _ = await requestHealthOperation(authorizing: true, force: true)
    }
    private func observe() {
        reader.observe { [weak self] in
            _ = await self?.requestHealthOperation(queueIfBusy: true)
        }
    }
    @discardableResult func refresh(force: Bool = false, rebuildingWorkouts: Bool = false) async -> WatchRefreshOutcome {
        await requestHealthOperation(force: force, rebuildingWorkouts: rebuildingWorkouts)
    }
    private func requestHealthOperation(authorizing: Bool = false, force: Bool = false,
                                       rebuildingWorkouts: Bool = false, queueIfBusy: Bool = false) async -> WatchRefreshOutcome {
        let token = generation
        if let current = healthOperation {
            if (authorizing && !authorizingOperation) || (rebuildingWorkouts && !rebuildingOperation) {
                _ = await current.value
                guard token == generation else { return .failed }
                return await requestHealthOperation(authorizing: authorizing, force: force, rebuildingWorkouts: rebuildingWorkouts)
            }
            if queueIfBusy { pendingRefresh = true }
            return await current.value
        }
        guard !busy else { status = "正在处理本地数据，请稍后重试连接。"; return .noSnapshot }
        if repository == nil {
            do { repository = try HealthRepository(file: repositoryFile); loadError = false }
            catch {
                loadError = true
                status = "本次连接未开始：本地缓存暂不可读取，原文件已保留。请解锁设备后重试。"
                return .failed
            }
        }
        let operationID = UUID()
        healthOperationID = operationID
        authorizingOperation = authorizing
        rebuildingOperation = rebuildingWorkouts
        busy = true
        status = authorizing ? "正在等待系统健康请求完成；请保持 App 前台。" : "正在读取 Apple 健康，完成后会更新本地报告。"
        let operation = Task<WatchRefreshOutcome, Never> { @MainActor [weak self] in
            guard let self else { return .failed }
            defer {
                if self.healthOperationID == operationID {
                    self.healthOperation = nil
                    self.healthOperationID = nil
                    self.authorizingOperation = false
                    self.rebuildingOperation = false
                    self.pendingRefresh = false
                    self.busy = false
                }
            }
            var outcome: WatchRefreshOutcome = .failed
            do {
                try Task.checkCancellation()
                if authorizing {
                    try await self.reader.authorize()
                    try Task.checkCancellation()
                    guard token == self.generation else { return .failed }
                    self.observe()
                }
                outcome = await self.readReport(force: force, rebuildingWorkouts: rebuildingWorkouts, token: token)
                if self.pendingRefresh, token == self.generation, outcome != .failed, !Task.isCancelled {
                    self.pendingRefresh = false
                    outcome = await self.readReport(force: false, rebuildingWorkouts: false, token: token)
                }
            } catch is CancellationError {
                if token == self.generation { self.status = "本次连接已取消，可再次点击连接重试。" }
            } catch {
                if token == self.generation { self.status = "无法完成健康读取请求，请检查设备支持情况及系统健康设置后重试。" }
            }
            return outcome
        }
        healthOperation = operation
        return await operation.value
    }
    private func readReport(force: Bool, rebuildingWorkouts: Bool, token: Int) async -> WatchRefreshOutcome {
        guard let repository else { return .failed }
        let initial = await repository.current()
        guard token == generation, !Task.isCancelled else { return .failed }
        guard initial.readingEnabled || force else {
            status = "请先点击“连接 Apple 健康”，完成系统请求后再读取。"
            return .needsHealthConnection
        }
        status = "正在读取 Apple 健康，完成后会更新本地报告。"
        var queryState = initial
        if rebuildingWorkouts { queryState.anchors = [:]; queryState.queryStart = nil }
        do {
            let now = Date()
            var batch = try await reader.readBatch(state: queryState, asOf: now)
            guard token == generation else { return .failed }
            let result: RepositoryState
            do { result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision) }
            catch DomainError.requiresFullReload {
                var reset = initial; reset.anchors = [:]
                batch = try await reader.readBatch(state: reset, asOf: now)
                guard token == generation else { return .failed }
                result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision)
            }
            guard token == generation else { return .failed }
            report = result.report; profile = result.profile; updateSources(result)
            planning = result.planning ?? PlanningState(); planningRevision = result.revision
            workoutRecords = result.records.filter { $0.kind == .workout }
            if let snapshot = result.snapshot { publish(snapshot) }
            await loadMoods(asOf: now)
            guard token == generation else { return .failed }
            await deliverMorningBrief(report: result.report, now: now, token: token)
            guard token == generation, !Task.isCancelled else { return .failed }
            status = result.records.isEmpty ? "暂无可读取记录；可能尚无记录或未允许读取，请检查健康 App。" : "已更新本地报告 · 估算仅供日常趋势参考"
            return result.snapshot == nil ? .noSnapshot : .snapshotAvailable
        } catch is CancellationError {
            if token == generation { status = "刷新已取消" }
        } catch {
            if token == generation { status = "刷新未完成，保留上次报告。请检查健康设置后重试。" }
        }
        return .failed
    }
    func enableDemo() async {
        demoEnabled = true
        if demo == nil {
            do { demo = try await Task.detached { try DemoData.report() }.value }
            catch { status = "演示加载失败" }
        }
        demoMoods = DemoData.moods(asOf: demo?.asOf ?? DemoData.previewDate)
        demoPlanning = PlanningState.demo(at: demo?.asOf ?? DemoData.previewDate, timeZoneID: demo?.timeZoneID ?? profile.timeZoneID)
        let now = demo?.asOf ?? DemoData.previewDate
        let config = AutomaticPlanConfiguration(experience: .starting, activities: [.walking], weekdays: Set(1...7), maximumMinutes: 30)
        if let clock = try? AnalysisClock(timeZoneID: planningTimeZone),
           let week = try? AutomaticWeekPlanner.generate(config, starting: now, timeZoneID: planningTimeZone) {
            try? demoPlanning.acceptAutomatic(week, at: clock.shiftedDay(now, by: -1), timeZoneID: planningTimeZone)
        }
        var sample = HealthRecord(id: "synthetic-completed-walk", kind: .workout, start: now.addingTimeInterval(-600), end: now,
                                 workoutType: AutomaticActivity.walking.workoutType, source: SampleSource(bundle: "synthetic.watch", family: "Watch", rank: 0))
        sample.workoutDurationSeconds = 600; sample.workoutActiveIntervals = [sample.interval]
        demoWorkoutRecords = [sample]
    }
    func completion(for entry: MovementEntry, at day: Date) -> WorkoutCompletion? {
        guard let activity = AutomaticActivity.matchingTitle(entry.activity) else { return nil }
        var configuration = profile; configuration.timeZoneID = planningTimeZone
        return try? WorkoutCompletion(activity: activity, targetMinutes: entry.minutes, day: day, records: displayedWorkoutRecords,
                                      profile: configuration, asOf: planningNow)
    }
    func updatePlanning(expectedDemo: Bool? = nil, _ change: (inout PlanningState) throws -> Void) async -> Bool {
        guard expectedDemo == nil || expectedDemo == demoEnabled else { return false }
        guard !planningBusy, !busy, !loadError else {
            planningNotice = "正在处理数据，请稍后重试。"; return false
        }
        let isDemo = demoEnabled
        let token = generation
        let revision = planningRevision
        var next = displayedPlanning
        planningBusy = true
        defer { planningBusy = false }
        do {
            try change(&next)
            try next.validate(asOf: planningNow)
            if isDemo { demoPlanning = next }
            else {
                guard let repository else { throw DomainError.invalidConfiguration }
                let result = try await repository.savePlanning(next, asOf: Date(), expectedRevision: revision)
                guard generation == token else { return false }
                planning = result.planning ?? PlanningState(); planningRevision = result.revision
            }
            planningNotice = "已保存在本机" + (isDemo ? "（仅合成演示）" : "")
            return true
        } catch {
            if !isDemo, let repository, generation == token {
                let current = await repository.current()
                guard generation == token else { return false }
                planning = current.planning ?? PlanningState(); planningRevision = current.revision
            }
            planningNotice = "未保存：请检查数值、日期或是否有更新冲突，原数据未被覆盖。"
            return false
        }
    }
    func markMovement(_ status: MovementStatus, at selectedDate: Date, expectedDemo: Bool, light: Bool = false) async {
        let zone = planningTimeZone
        _ = await updatePlanning(expectedDemo: expectedDemo) { try $0.mark(status, at: selectedDate, timeZoneID: zone, useLight: light) }
    }
    /// Notifications are requested only when the user turns the brief on; a refusal keeps it off.
    func setMorningBrief(enabled: Bool) async {
        morningBriefEnabled = enabled   // reflect the tap at once; revert below if permission is refused
        guard enabled else { UserDefaults.standard.set(false, forKey: "morningBriefEnabled"); morningBriefNotice = nil; return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        morningBriefEnabled = granted
        UserDefaults.standard.set(granted, forKey: "morningBriefEnabled")
        morningBriefNotice = granted ? nil : "通知权限未开启，晨报保持关闭。可在系统设置中允许 Wristlab 通知。"
    }
    /// Called when settings appear: the user may have revoked notifications in system settings.
    func checkMorningBriefPermission() async {
        guard morningBriefEnabled else { morningBriefNotice = nil; return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        morningBriefNotice = status == .authorized || status == .provisional ? nil : "系统已关闭 Wristlab 通知，晨报不会送达。可在系统设置中重新允许。"
    }
    func setMorningBrief(showValues: Bool) {
        morningBriefShowsValues = showValues
        UserDefaults.standard.set(showValues, forKey: "morningBriefShowValues")
    }
    /// Real refreshes only; at most one brief per analysis day.
    private func deliverMorningBrief(report: HealthReport?, now: Date, token: Int) async {
        guard morningBriefEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // A clear or stop while waiting wins: never notify with data that was just removed.
        guard token == generation, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let lastSent = UserDefaults.standard.string(forKey: "morningBriefLastDay")
        guard let brief = MorningBrief.make(report: report, lastSentDay: lastSent, hideValues: !morningBriefShowsValues, now: now) else { return }
        // Claim the day before the await so an overlapping refresh cannot send a second one.
        UserDefaults.standard.set(brief.dayKey, forKey: "morningBriefLastDay")
        let content = UNMutableNotificationContent()
        content.title = brief.title
        content.body = brief.body
        do {
            try await center.add(UNNotificationRequest(identifier: "morning-brief-\(brief.dayKey)", content: content, trigger: nil))
        } catch {
            // Release the claim so a later refresh can try again the same day.
            UserDefaults.standard.set(lastSent, forKey: "morningBriefLastDay")
        }
    }
    /// Asked only when the user taps connect; an empty read never implies denial.
    func connectMoods() async {
        do {
            try await reader.authorizeMoods()
            moodConnected = true
            UserDefaults.standard.set(true, forKey: "moodReadingRequested")
            // Recompute so moods logged after the last report can be paired; without health reading just list them.
            await refresh()
            await loadMoods(asOf: Date())
        } catch { moodStatus = "无法完成心情读取请求，请检查系统健康设置。" }
    }
    private func loadMoods(asOf now: Date) async {
        guard moodConnected, let clock = try? AnalysisClock(timeZoneID: profile.timeZoneID) else { return }
        let token = generation
        do {
            let read = try await reader.readMoods(from: clock.shiftedDay(clock.day(containing: now).start, by: -6))
            // A clear or stop during the read wins; drop the stale result.
            guard token == generation, moodConnected else { return }
            moods = read
            moodStatus = nil
        } catch { if token == generation { moodStatus = "心情记录读取未完成，保留上次结果。" } }
    }
    func save(_ updated: HealthProfile) async {
        guard !busy, !planningBusy, let repository else { return }
        generation += 1; busy = true
        do {
            let state = try await repository.configure(updated, asOf: Date())
            planning = state.planning ?? PlanningState(); planningRevision = state.revision
            workoutRecords = state.records.filter { $0.kind == .workout }
            profile = state.profile; report = state.report
            if let snapshot = state.snapshot { publish(snapshot) }
            status = "设置已保存，已按新配置重算本地历史。"
        } catch { status = "设置无效或保存失败，已保留原配置。" }
        busy = false
        await refresh()
    }
    func clear(stop: Bool) async {
        guard let repository else { return }
        generation += 1; pendingRefresh = false
        let token = generation
        healthOperation?.cancel()
        healthOperation = nil
        healthOperationID = nil
        authorizingOperation = false
        rebuildingOperation = false
        busy = true
        if stop { reader.stop() } else { reader.cancelRead() }
        do {
            let state = try await repository.clear(stopReading: stop, asOf: Date())
            guard token == generation else { return }
            contentResetID = UUID()
            planning = state.planning ?? PlanningState(); planningRevision = state.revision
            workoutRecords = state.records.filter { $0.kind == .workout }
            report = nil; moods = []; moodStatus = nil
            // Delivered briefs may show values that were just cleared.
            clearNotifications()
            if stop {
                // Stopping reading also forgets the mood request; reconnecting asks again on the mood card.
                moodConnected = false
                UserDefaults.standard.removeObject(forKey: "moodReadingRequested")
            }
            if let snapshot = state.snapshot { publish(snapshot) }
            status = stop ? "本地数据、计划与体重已清除 · 等待手表同步" : "派生缓存已清除，计划与手动体重已保留"
            busy = false
            if !stop, state.readingEnabled { await refresh() }
        } catch {
            if token == generation { status = "清除未完成，原数据保持不变。" }
        }
        if token == generation, healthOperation == nil { busy = false }
    }
    private func publish(_ snapshot: DisplaySnapshot) {
        bridge.publish(snapshot)
        PhoneWidgetStore.publish(snapshot)
    }
    private func updateSources(_ state: RepositoryState) {
        sources = Dictionary(grouping: state.records, by: \.kind).mapValues { Array(Set($0.map { $0.source.group })).sorted() }
    }
}
