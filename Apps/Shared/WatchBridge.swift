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
    var onRefresh: (@MainActor () async -> Void)?
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
        guard let session, session.isReachable else { status = "手机不可达 · 保留上次数据"; return }
        status = "已请求手机刷新"
        session.sendMessage(["refresh": true], replyHandler: nil) { _ in Task { @MainActor in self.status = "刷新未送达，请稍后重试" } }
    }
    func confirmProducer() {
        guard let pendingProducer else { return }; accept(pendingProducer, confirm: true)
    }
    private func accept(_ value: DisplaySnapshot, confirm: Bool = false) {
        var next = receiver
        do {
            try next.accept(value, confirmProducer: confirm || receiver.snapshot == nil)
            let data = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var folder = Self.cacheURL.deletingLastPathComponent()
            var policy = URLResourceValues(); policy.isExcludedFromBackup = true
            try folder.setResourceValues(policy)
            try data.write(to: Self.cacheURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            receiver = next; snapshot = next.snapshot; pendingProducer = nil
            status = value.clearData ? "手机数据已清除" : "已收到手机数据"
            #if os(watchOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch DomainError.producerConfirmationRequired { pendingProducer = value; status = "请确认连接新手机数据" }
        catch { status = "已忽略旧版或无效快照" }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
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
        if message["refresh"] as? Bool == true { Task { @MainActor in await self.onRefresh?() } }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
