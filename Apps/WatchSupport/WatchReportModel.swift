import Foundation
import Combine
import WristlabCore
#if SWIFT_PACKAGE
import SnapshotStorage
#endif

@MainActor public final class WatchReportModel: ObservableObject {
    @Published public private(set) var envelope: WatchDisplayEnvelope?
    @Published public private(set) var profile = HealthProfile()
    @Published public private(set) var busy = false
    @Published public private(set) var cleaning = false
    @Published public private(set) var status = "请选择报告来源"
    @Published public private(set) var notice: String?
    @Published public private(set) var phoneSnapshot: DisplaySnapshot?
    @Published public private(set) var localSnapshot: DisplaySnapshot?
    public var onDisplayChanged: (() -> Void)?
    public var onClearLocal: (() throws -> Void)?
    public var snapshot: DisplaySnapshot? { envelope?.snapshot }
    private let reader: any WatchHealthReading
    private let repository: HealthRepository?
    private let store: WatchDisplayStore?
    private let now: () -> Date
    private var operationID: UUID?
    private var queuedRefresh = false
    private var started = false
    private var starting = false
    private var demo = false
    private var localReport: HealthReport?
    private enum NoticeKind { case cache, cleanup, localOperation, phoneProjection }
    private var noticeKind: NoticeKind?
    private static let cacheNotice = "本地缓存不可读取，已保留文件；请解锁后重试。"
    private static let cleanupNotice = "手表已停止显示和读取，清理未完成；请重试，不会自动恢复旧数据。"

    public init(reader: any WatchHealthReading, repository: HealthRepository?, store: WatchDisplayStore?, phone: DisplaySnapshot?, now: @escaping () -> Date = { Date() }) {
        self.reader = reader
        self.repository = repository
        self.store = store
        phoneSnapshot = phone ?? (store?.envelope.mode == .phone ? store?.envelope.snapshot : nil)
        self.now = now
        envelope = store?.envelope
        if repository == nil || store == nil { presentNotice(Self.cacheNotice, kind: .cache) }
    }
    private func presentNotice(_ value: String?, kind: NoticeKind? = nil) {
        notice = value
        noticeKind = kind
    }
    private func restorePersistentNotice() -> Bool {
        if envelope?.cleanupPending == true {
            status = "手表已停止，等待完成清理"
            presentNotice(Self.cleanupNotice, kind: .cleanup)
            return true
        }
        if repository == nil || store == nil {
            presentNotice(Self.cacheNotice, kind: .cache)
            return true
        }
        return false
    }
    private func commit(_ value: WatchDisplayEnvelope) throws {
        guard let store else { throw DomainError.invalidSnapshot }
        var next = value
        if value.mode == .local, value.localState == .enabled, !value.cleanupPending,
           let report = localReport, let snapshot = value.snapshot, report.source == .healthKit,
           report.asOf == snapshot.asOf, report.configurationVersion == snapshot.configurationVersion,
           report.timeZoneID == snapshot.timeZoneID {
            var care = value.careProjection ?? WatchCareProjection()
            care.context = CareReportContext(report: report, snapshot: snapshot)
            next = try value.updatingCare(care)
        }
        if try JSONEncoder().encode(next).count > 40000 {
            var care = next.careProjection
            care?.context?.points = []
            care?.context?.graphNotice = "趋势超出展示上限，未绘图。"
            next = try next.updatingCare(care)
        }
        try store.commit(next)
        envelope = store.envelope
        onDisplayChanged?()
    }
    public func updateActivity(_ daily: DailyActivityReport?) throws {
        guard !demo, let envelope, !envelope.cleanupPending else { throw DomainError.invalidSnapshot }
        var care = envelope.careProjection ?? WatchCareProjection()
        care.daily = daily
        try commit(envelope.updatingCare(care))
    }
    private func invalidate() {
        operationID = nil
        queuedRefresh = false
        busy = false
        reader.cancel()
        status = envelope?.mode?.title ?? "请选择报告来源"
    }
    public func start() async {
        guard !started, !demo, let repository, store != nil else { return }
        started = true
        starting = true
        defer { starting = false }
        guard await finishCleanup() else { return }
        let state = await repository.current()
        profile = state.profile
        localReport = state.report
        localSnapshot = envelope?.localState == .enabled ? state.snapshot : nil
        if envelope?.mode == .local, envelope?.localState == .enabled { await refreshLocal() }
        else if envelope?.mode == .phone { receivePhone(phoneSnapshot) }
        else { status = "选择来源后连接健康" }
    }
    public func foreground() async {
        guard !demo, !starting else { return }
        if !started { await start(); return }
        guard await finishCleanup() else { return }
        if envelope?.mode == .local, envelope?.localState == .enabled { await refreshLocal() }
        else if envelope?.mode == .phone { receivePhone(phoneSnapshot) }
    }
    public func setDemo(_ enabled: Bool) async {
        demo = enabled
        invalidate()
        if !enabled, envelope?.mode == .local { await refreshLocal() }
        else if !enabled, envelope?.mode == .phone { receivePhone(phoneSnapshot) }
    }
    public func receivePhone(_ value: DisplaySnapshot?) {
        guard let value else { return }
        guard value.source == .healthKit, (try? value.validate()) != nil else {
            presentNotice("已忽略非真实或无效的手机快照。", kind: .phoneProjection)
            _ = restorePersistentNotice()
            return
        }
        phoneSnapshot = value
        guard !demo, let envelope else { return }
        guard envelope.mode == .phone else {
            if restorePersistentNotice() { return }
            if value.clearData { status = "手机同步副本已清除 · 当前仍使用手表本地报告" }
            return
        }
        do {
            try commit(envelope.projecting(value, from: .phone))
            status = value.clearData ? "手机同步副本已清除" : "已收到手机快照"
            if !restorePersistentNotice(), noticeKind == .phoneProjection { presentNotice(nil) }
        } catch {
            status = "手机展示更新未完成"
            presentNotice("手机副本已保存，但展示缓存更新失败，请重试。", kind: .phoneProjection)
            _ = restorePersistentNotice()
        }
    }
    public func select(_ mode: WatchReportMode) async {
        guard !demo, !cleaning, let repository, envelope != nil else { return }
        invalidate()
        let token = UUID()
        operationID = token
        let state = await repository.current()
        guard operationID == token, let current = envelope else { return }
        localReport = state.report
        do {
            localSnapshot = current.localState == .enabled ? state.snapshot : nil
            let selected = mode == .phone ? phoneSnapshot : localSnapshot
            try commit(current.selecting(mode, snapshot: selected?.clearData == true && mode == .local ? nil : selected))
            status = mode.title
            if !restorePersistentNotice() { presentNotice(nil) }
        } catch {
            status = "来源切换未保存"
            presentNotice("来源切换未保存，仍保留原报告。", kind: .localOperation)
            _ = restorePersistentNotice()
        }
        if operationID == token { operationID = nil }
    }
    public func connectLocal() async {
        guard !demo, !busy, !cleaning, repository != nil, store != nil else { return }
        guard await finishCleanup() else { return }
        let token = UUID()
        operationID = token
        busy = true
        presentNotice(nil)
        status = "正在请求手表健康访问"
        do {
            try await reader.authorize()
            guard operationID == token, !demo, let repository else { return }
            let stored = await repository.current()
            guard operationID == token, !demo, let envelope else { return }
            let previous = envelope.localState == .enabled && stored.snapshot?.clearData != true ? stored.snapshot : nil
            try commit(envelope.enablingLocal().selecting(.local, snapshot: previous))
            busy = false
            operationID = nil
            await refreshLocal()
        } catch {
            guard operationID == token else { return }
            busy = false
            operationID = nil
            status = "手表健康连接未完成"
            presentNotice("手表健康连接未完成，保留原报告，请检查系统健康设置。", kind: .localOperation)
        }
    }
    public func refreshLocal() async {
        guard !demo, !cleaning, let repository, envelope?.mode == .local, envelope?.localState == .enabled else { return }
        if busy { queuedRefresh = true; return }
        let token = UUID()
        operationID = token
        busy = true
        presentNotice(nil)
        status = "正在读取手表健康记录"
        defer {
            if operationID == token {
                busy = false
                operationID = nil
                if queuedRefresh {
                    queuedRefresh = false
                    Task { await self.refreshLocal() }
                }
            }
        }
        do {
            let initial = await repository.current()
            guard operationID == token, !demo else { return }
            if let envelope, let saved = initial.snapshot, !saved.clearData {
                localSnapshot = saved
                localReport = initial.report
                try commit(envelope.projecting(saved, from: .local))
            }
            let now = now()
            var batch = try await reader.readBatch(state: initial, asOf: now)
            guard operationID == token, !demo else { return }
            let result: RepositoryState
            do { result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision) }
            catch DomainError.requiresFullReload {
                var reset = initial
                reset.anchors = [:]
                batch = try await reader.readBatch(state: reset, asOf: now)
                guard operationID == token, !demo else { return }
                result = try await repository.apply(batch, asOf: now, expectedRevision: initial.revision)
            }
            guard operationID == token, !demo, let envelope else { return }
            profile = result.profile
            localSnapshot = result.snapshot
            localReport = result.report
            try commit(envelope.projecting(result.snapshot, from: .local))
            status = result.records.isEmpty ? "手表暂无可读取记录；可能无记录、未允许读取或尚未同步。" : "手表本地报告已更新"
        } catch {
            guard operationID == token, !demo else { return }
            status = "本地刷新未完成"
            presentNotice("本地刷新或展示保存未完成，保留上次已提交报告，请稍后重试。", kind: .localOperation)
        }
    }
    public func configure(_ profile: HealthProfile) async {
        guard !demo, !busy, !cleaning, let repository else { return }
        guard await finishCleanup() else { return }
        let token = UUID()
        operationID = token
        busy = true
        defer { if operationID == token { operationID = nil; busy = false } }
        do {
            try profile.validate()
            let state = try await repository.configure(profile, asOf: now())
            guard operationID == token, !demo else { return }
            self.profile = state.profile
            localReport = state.report
            localSnapshot = envelope?.localState == .enabled ? state.snapshot : nil
            if let envelope, envelope.mode == .local, envelope.localState == .enabled {
                try commit(envelope.projecting(state.snapshot, from: .local))
            }
            presentNotice(nil)
            status = "手表设置已保存 · 不会自动同步手机设置"
        } catch {
            if operationID == token {
                status = "设置或展示保存未完成"
                presentNotice("设置或展示保存失败，请检查范围并重试。", kind: .localOperation)
            }
        }
    }
    public func prepareSettings() async {
        guard let repository else { return }
        profile = await repository.current().profile
    }
    public func stopLocal() async {
        guard !demo, !cleaning, let envelope, store != nil else { return }
        invalidate()
        do { try commit(envelope.stoppingLocal()) }
        catch {
            status = "清除未完成"
            presentNotice("停止标记未保存，清除未完成；已取消当前读取，请重试。", kind: .localOperation)
            _ = restorePersistentNotice()
            return
        }
        localSnapshot = nil
        localReport = nil
        _ = await finishCleanup()
    }
    private func finishCleanup() async -> Bool {
        guard envelope?.cleanupPending == true else { return true }
        guard !cleaning else { return false }
        cleaning = true
        defer { cleaning = false }
        do {
            try onClearLocal?()
            guard let repository else { throw DomainError.invalidSnapshot }
            _ = try await repository.clear(stopReading: true, asOf: now())
            guard let envelope else { return false }
            try commit(envelope.finishingCleanup())
            status = "手表读取已停止，本地数据已清除"
            presentNotice(nil)
            return true
        } catch {
            status = "手表已停止，等待完成清理"
            presentNotice(Self.cleanupNotice, kind: .cleanup)
            return false
        }
    }
}
