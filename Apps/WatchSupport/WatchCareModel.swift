import Foundation
import Combine
import WristlabCore
#if SWIFT_PACKAGE
import SnapshotStorage
#endif

@MainActor public final class WatchCareModel: ObservableObject {
    @Published public private(set) var busy = false
    @Published public private(set) var notice: String?
    @Published public private(set) var status = "主动连接日常活动后读取步数与圆环。"
    @Published public private(set) var generation = UUID()
    public var publishActivity: ((DailyActivityReport?) throws -> Void)?
    public var canUse: () -> Bool = { true }
    public var activityEnabled: Bool { store?.state.activityEnabled == true }
    public var mood: CareMoodRecord? {
        guard !demo, canUse(), let mood = store?.state.mood,
              mood.isCurrent(at: now(), timeZoneID: timeZoneID()) else { return nil }
        return mood
    }
    private let reader: any DailyActivityReading
    private let store: CareStateStore?
    private let now: () -> Date
    private let timeZoneID: () -> String
    private var operation: UUID?
    private var demo = false
    public init(reader: any DailyActivityReading, store: CareStateStore?, now: @escaping () -> Date = { Date() },
                timeZoneID: @escaping () -> String = { TimeZone.current.identifier }) {
        self.reader = reader; self.store = store; self.now = now; self.timeZoneID = timeZoneID
        if store == nil { notice = "关怀记录暂不可读取，已保留原文件，请解锁后重试。" }
    }
    public func invalidate() {
        generation = UUID(); operation = nil; reader.cancel(); busy = false
        status = "当前操作已结束，可重新刷新。"
    }
    public func setDemo(_ value: Bool) { demo = value; invalidate() }
    public func foreground() async {
        guard !demo, canUse(), let store else { return }
        do {
            var state = store.state
            if let mood = state.mood, !mood.isCurrent(at: now(), timeZoneID: timeZoneID()) {
                state.mood = nil; try store.save(state); generation = UUID()
            }
            try publishActivity?(state.activityEnabled ? state.daily : nil)
            if state.activityEnabled { await refresh() }
            else { notice = nil; status = "活动读取已停止，可主动重新连接。" }
        } catch { notice = "本机记录或展示更新未完成，保留已提交内容，请重试。" }
    }
    public func connect() async {
        guard !demo, !busy, canUse(), let store else { return }
        let token = UUID(); operation = token; busy = true
        status = "正在请求日常活动读取"; notice = nil
        defer { if operation == token { operation = nil; busy = false } }
        do {
            try await reader.authorize()
            guard operation == token, !demo, canUse() else { return }
            var state = store.state; state.activityEnabled = true
            try store.save(state)
            operation = nil; busy = false
            await refresh()
        } catch {
            guard operation == token else { return }
            operation = nil; busy = false; status = "活动连接未完成"
            notice = "未完成活动连接或保存，请重试；空读取不表示拒绝授权。"
        }
    }
    public func refresh() async {
        guard !demo, !busy, canUse(), let store, store.state.activityEnabled else { return }
        let token = UUID(); operation = token; busy = true
        let instant = now(), zone = timeZoneID()
        status = "正在读取日常活动"; notice = nil
        defer { if operation == token { operation = nil; busy = false } }
        do {
            if let saved = store.state.daily { try publishActivity?(saved) }
            let result = try await reader.read(at: instant, timeZoneID: zone)
            guard operation == token, !demo, canUse(), zone == timeZoneID(),
                  let clock = try? AnalysisClock(timeZoneID: zone), clock.label(instant) == clock.label(now()) else {
                if operation == token { status = "日期或来源变化，请重新刷新。" }
                return
            }
            try result.validate()
            var merged = result
            if let old = store.state.daily, old.day == result.day, old.timeZoneID == result.timeZoneID {
                if result.stepsFailed { merged.steps = old.steps; merged.stepsReadAt = old.stepsReadAt }
                if result.ringsFailed { merged.rings = old.rings; merged.ringsReadAt = old.ringsReadAt }
            }
            var state = store.state; state.daily = merged
            try store.save(state)
            try publishActivity?(merged)
            status = result.stepsFailed || result.ringsFailed ? "部分读取未完成，保留对应旧记录时间。" : "日常活动已更新；无结果可能尚无记录、未允许读取或未同步。"
            generation = UUID()
        } catch {
            guard operation == token else { return }
            status = "活动刷新未完成"
            notice = "读取、本机保存或展示更新未完成；保留上次已提交记录，可重试。"
        }
    }
    public func stopActivity() throws {
        guard !demo, canUse(), let store else { throw DomainError.invalidSnapshot }
        invalidate()
        var state = store.state; state.activityEnabled = false; state.daily = nil
        do { try store.save(state); try publishActivity?(nil); notice = nil; status = "活动读取已停止，心情与状态报告保留。" }
        catch { notice = "停止或展示更新未保存，请重试。"; throw error }
    }
    public func clearAll() throws {
        invalidate()
        guard let store else { throw DomainError.invalidSnapshot }
        try store.save(CareState())
        notice = nil; status = "本机关怀记录已清除。"
    }
    public func saveMood(_ mood: CareMood?, capturedAt: Date, capturedZone: String, expectedGeneration: UUID) throws {
        guard !demo, canUse(), let store, generation == expectedGeneration, capturedZone == timeZoneID(),
              let clock = try? AnalysisClock(timeZoneID: capturedZone), clock.label(capturedAt) == clock.label(now()), capturedAt <= now() else { throw DomainError.staleRevision }
        var state = store.state
        state.mood = try mood.map { try CareMoodRecord(mood: $0, at: now(), timeZoneID: capturedZone) }
        try store.save(state)
        generation = UUID()
    }
}
