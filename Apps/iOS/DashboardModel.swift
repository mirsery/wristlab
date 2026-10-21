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
    private let reader = HealthKitReader()
    private var repository: HealthRepository?
    private var generation = 0
    private var pendingRefresh = false
    private var loadError = false
    var displayed: HealthReport? { demoEnabled ? demo : report }
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Wristlab")
        do { repository = try HealthRepository(file: base.appendingPathComponent("health-state.json")) }
        catch { loadError = true; status = "本地缓存不可读取，请保留文件并重试，未覆盖原数据。" }
        bridge.onRefresh = { [weak self] in await self?.refresh() }
    }
    func restoreObservers() async {
        guard let repository else { return }
        let state = await repository.current()
        if state.readingEnabled { observe() }
    }
    func start() async {
        if repository == nil {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Wristlab")
            do { repository = try HealthRepository(file: base.appendingPathComponent("health-state.json")); loadError = false }
            catch { status = "本地缓存暂不可读取，已保留原文件，请解锁设备后重试。" }
        }
        guard let repository else { return }
        let state = await repository.current(); profile = state.profile; report = state.report
        if let snapshot = state.snapshot { publish(snapshot) }
        updateSources(state)
        if ProcessInfo.processInfo.arguments.contains("--demo") { await enableDemo(); return }
        if state.readingEnabled { observe(); await refresh() }
    }
    func connect() async {
        guard !busy, !loadError else { return }
        do { try await reader.authorize(); observe(); await refresh(force: true) }
        catch { status = "无法完成健康读取请求，请检查设备支持情况及系统健康设置。" }
    }
    private func observe() { reader.observe { [weak self] in await self?.refresh() } }
    func refresh(force: Bool = false) async {
        guard let repository else { return }
        if busy { pendingRefresh = true; return }
        let initial = await repository.current()
        guard initial.readingEnabled || force else { return }
        busy = true; let token = generation
        defer {
            busy = false
            if pendingRefresh { pendingRefresh = false; Task { await refresh() } }
        }
        do {
            let now = Date()
            var batch = try await reader.readBatch(state: initial, asOf: now)
            guard token == generation else { return }
            let result: RepositoryState
            do { result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision) }
            catch DomainError.requiresFullReload {
                var reset = initial; reset.anchors = [:]
                batch = try await reader.readBatch(state: reset, asOf: now)
                guard token == generation else { return }
                result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision)
            }
            guard token == generation else { return }
            report = result.report; profile = result.profile; updateSources(result)
            if let snapshot = result.snapshot { publish(snapshot) }
            await loadMoods(asOf: now)
            guard token == generation else { return }
            await deliverMorningBrief(report: result.report, now: now, token: token)
            status = result.records.isEmpty ? "暂无可读取记录；可能尚无记录或未允许读取，请检查健康 App。" : "已更新本地报告 · 估算仅供日常趋势参考"
        } catch is CancellationError {
            if token == generation { status = "刷新已取消" }
        } catch {
            if token == generation { status = "刷新未完成，保留上次报告。请检查健康设置后重试。" }
        }
    }
    func enableDemo() async {
        demoEnabled = true
        if demo == nil {
            do { demo = try await Task.detached { try DemoData.report() }.value }
            catch { status = "演示加载失败" }
        }
        demoMoods = DemoData.moods(asOf: demo?.asOf ?? DemoData.previewDate)
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
        guard !busy, let repository else { return }
        generation += 1; busy = true
        do {
            let state = try await repository.configure(updated, asOf: Date())
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
        if stop { reader.stop() }
        do {
            let state = try await repository.clear(stopReading: stop, asOf: Date())
            report = nil; moods = []; moodStatus = nil
            // Delivered briefs may show values that were just cleared.
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            if stop {
                // Stopping reading also forgets the mood request; reconnecting asks again on the mood card.
                moodConnected = false
                UserDefaults.standard.removeObject(forKey: "moodReadingRequested")
            }
            if let snapshot = state.snapshot { publish(snapshot) }
            status = "本地数据已清除 · 等待手表同步"
            if !stop, state.readingEnabled { await refresh() }
        } catch { status = "清除未完成，原数据保持不变。" }
    }
    private func publish(_ snapshot: DisplaySnapshot) {
        bridge.publish(snapshot)
        PhoneWidgetStore.publish(snapshot)
    }
    private func updateSources(_ state: RepositoryState) {
        sources = Dictionary(grouping: state.records, by: \.kind).mapValues { Array(Set($0.map { $0.source.group })).sorted() }
    }
}
