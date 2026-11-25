import Foundation
@preconcurrency import WatchConnectivity
import Combine
import WristlabCore
#if os(watchOS)
import WidgetKit
#endif

@MainActor
final class WatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: DisplaySnapshot?
    @Published var pendingProducer: DisplaySnapshot?
    @Published var status = "等待连接"
    var onRefresh: (@MainActor () async -> WatchRefreshOutcome)?
    var onPrepareSnapshot: (@MainActor () async -> Void)?
    var onSnapshotReceived: (@MainActor (DisplaySnapshot) -> Void)?
    private var refreshState = WatchRefreshState()
    private var refreshTimeout: Task<Void, Never>?
    private var outgoing: Data?
    private var receiver = SnapshotReceiver()
    private let session: WCSession?
    private static var cacheURL: URL {
        #if os(watchOS)
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mirsery.wristlab.watch") ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #endif
        return base.appendingPathComponent("watch-receiver.json")
    }
    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        if let data = try? Data(contentsOf: Self.cacheURL), let cached = try? JSONDecoder().decode(SnapshotReceiver.self, from: data), (try? cached.snapshot?.validate()) != nil {
            receiver = cached; snapshot = cached.snapshot
        }
        session?.delegate = self; session?.activate()
    }
    func publish(_ snapshot: DisplaySnapshot) {
        guard snapshot.source == .healthKit, let data = try? snapshot.encoded() else { return }
        outgoing = data; sendLatest()
    }
    private func sendLatest() {
        guard let session, session.activationState == .activated, let outgoing else { return }
        do { try session.updateApplicationContext(["snapshot": outgoing]); status = "已提交同步 · 由系统择机送达" }
        catch { status = "等待手表连接后同步" }
    }
    func requestRefresh() {
        let requestID = UUID()
        guard refreshState.begin(requestID, reachable: session?.isReachable == true, activated: session?.activationState == .activated) else {
            if refreshState.phase == .activationFailed { status = "连接尚未激活 · 请稍后重试" }
            if refreshState.phase == .unreachable { status = "手机不可达 · 请打开手机 Wristlab" }
            return
        }
        guard let session else { return }
        status = "等待手机响应"
        refreshTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, self.refreshState.requestID == requestID else { return }
            self.refreshState.complete(requestID, phase: .timedOut)
            self.status = "手机未回应 · 请检查手机版本并重试"
        }
        let handlers = WatchRefreshHandlers(requestID: requestID) { [weak self] response in
            self?.finishRefresh(requestID, response)
        }
        session.sendMessage(["refresh": true, "requestID": requestID.uuidString, "refreshProtocol": 1],
                            replyHandler: handlers.reply, errorHandler: handlers.failure)
    }
    private func finishRefresh(_ requestID: UUID, _ response: WatchRefreshResponse) {
        guard refreshState.requestID == requestID else { return }
        refreshTimeout?.cancel()
        switch response {
        case .undelivered:
            refreshState.complete(requestID, phase: .failed)
            status = "刷新未送达 · 请检查手机版本与连接"
        case .unreadable:
            refreshState.complete(requestID, phase: .failed)
            status = "手机回复无法识别 · 请检查双端版本"
        case .reply(let value):
            refreshState.complete(requestID, phase: .idle)
            if let snapshot = value.snapshot, let decoded = try? DisplaySnapshot.decode(snapshot) { accept(decoded) }
            else {
                switch value.outcome {
                case .needsHealthConnection: status = "请在手机连接 Apple 健康"
                case .noSnapshot: status = "手机暂无可同步快照 · 请在手机刷新"
                case .failed: status = "手机刷新未完成 · 保留上次数据"
                case .snapshotAvailable: status = "手机快照无效 · 请重新刷新"
                }
            }
        }
    }
    func confirmProducer() {
        guard let pendingProducer else { return }; accept(pendingProducer, confirm: true)
    }
    private func finishPendingRefresh() {
        if let requestID = refreshState.requestID {
            refreshState.complete(requestID, phase: .idle)
            refreshTimeout?.cancel()
        }
    }
    private func accept(_ value: DisplaySnapshot, confirm: Bool = false) {
        do {
            try WatchSnapshotDelivery.accept(value, receiver: &receiver, confirmProducer: confirm || receiver.snapshot == nil) {
                try SnapshotCacheFile.write($0, to: Self.cacheURL)
            }
            snapshot = receiver.snapshot; pendingProducer = nil
            onSnapshotReceived?(value)
            finishPendingRefresh()
            status = value.clearData ? "手机数据已清除" : "已收到手机数据"
            #if os(watchOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch DomainError.producerConfirmationRequired {
            finishPendingRefresh()
            pendingProducer = value; status = "请确认连接新手机数据"
        }
        catch is DomainError { status = "已忽略旧版或无效快照" }
        catch { finishPendingRefresh(); status = "快照保存失败，请重试同步" }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            guard error == nil, activationState == .activated else {
                self.finishPendingRefresh()
                self.status = "连接激活失败 · 请重新打开双端 App"
                return
            }
            self.sendLatest()
            #if os(watchOS)
            if let data = session.receivedApplicationContext["snapshot"] as? Data, let value = try? DisplaySnapshot.decode(data) { self.accept(value) }
            #endif
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data, let value = try? DisplaySnapshot.decode(data) else { return }
        #if os(watchOS)
        Task { @MainActor in self.accept(value) }
        #endif
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        #if os(iOS)
        if message["refresh"] as? Bool == true { Task { @MainActor in _ = await self.onRefresh?() } }
        #endif
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping @Sendable ([String: Any]) -> Void) {
        let requestID = (message["requestID"] as? String).flatMap(UUID.init(uuidString:))
        let refresh = message["refresh"] as? Bool == true
        Task { @MainActor in
            #if os(iOS)
            guard refresh, let requestID else { replyHandler([:]); return }
            await WatchRefreshResponder.respond(requestID: requestID, cached: {
                await self.onPrepareSnapshot?()
                return self.outgoing
            }, refresh: {
                await self.onRefresh?() ?? .failed
            }, reply: { response in
                replyHandler(["refreshReply": (try? JSONEncoder().encode(response)) ?? Data()])
            })
            #else
            replyHandler([:])
            #endif
        }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
