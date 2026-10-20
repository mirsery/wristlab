import Foundation
import Combine
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
    func start() async {
        guard let repository else { return }
        let state = await repository.current(); profile = state.profile; report = state.report
        if let snapshot = state.snapshot { bridge.publish(snapshot) }
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
            if let snapshot = result.snapshot { bridge.publish(snapshot) }
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
    }
    func save(_ updated: HealthProfile) async {
        guard !busy, let repository else { return }
        generation += 1; busy = true
        do {
            let state = try await repository.configure(updated, asOf: Date())
            profile = state.profile; report = state.report
            if let snapshot = state.snapshot { bridge.publish(snapshot) }
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
            report = nil
            if let snapshot = state.snapshot { bridge.publish(snapshot) }
            status = "本地数据已清除 · 等待手表同步"
            if !stop, state.readingEnabled { await refresh() }
        } catch { status = "清除未完成，原数据保持不变。" }
    }
    private func updateSources(_ state: RepositoryState) {
        sources = Dictionary(grouping: state.records, by: \.kind).mapValues { Array(Set($0.map { $0.source.group })).sorted() }
    }
}
