import Foundation
import Combine
import WristlabCore

@MainActor
final class CloudPreferencesModel: ObservableObject {
    @Published private(set) var state: PreferenceSyncSnapshot?
    @Published private(set) var preferences = InterfacePreferences()
    @Published private(set) var working = false
    @Published private(set) var notice: String?
    @Published private(set) var contextID = UUID()
    @Published private(set) var preferenceRevision = UUID()
    private let coordinator: PreferenceSyncCoordinator?
    private var request = 0
    private var demo = false
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WristlabPreferences")
        do { coordinator = try PreferenceSyncCoordinator(backend: ApplePreferenceCloud(), file: directory.appendingPathComponent("preferences-v1.json")) }
        catch { coordinator = nil; notice = "界面偏好缓存暂不可读取，已保留原文件；云同步不可用，请解锁后重启重试。" }
    }
    private func apply(_ value: PreferenceSyncSnapshot) {
        if state?.account != value.account { contextID = UUID() }
        state = value; preferences = value.preferences; preferenceRevision = UUID()
        notice = value.phase == .failed ? "本次结果尚未完整确认，保留本机偏好；可能是网络、账户、配额、数据版本或本地保存问题，可检查账户后重试。" : nil
    }
    private func run(_ operation: (PreferenceSyncCoordinator) async -> PreferenceSyncSnapshot) async {
        guard !demo, !working, let coordinator else { return }
        let token = request
        working = true
        let value = await operation(coordinator)
        guard token == request, !demo else { return }
        apply(value); working = false
    }
    func checkAccount() async {
        await run { coordinator in
            let value = await coordinator.checkAccount()
            if value.enabled { return await coordinator.synchronize() }
            return value
        }
    }
    func enable() async { await run { await $0.enable() } }
    func synchronize() async { await run { await $0.synchronize() } }
    func resolve(_ choice: PreferenceResolution) async { await run { await $0.resolve(choice) } }
    func disable(clearLocal: Bool = false) async {
        guard !demo, let coordinator else { return }
        request += 1; working = false; contextID = UUID()
        let token = request
        let value = await coordinator.disable(clearLocal: clearLocal)
        guard token == request, !demo else { return }
        apply(value)
    }
    func deleteCloud() async { await run { await $0.deleteCloud() } }
    func edit(_ value: InterfacePreferences, context: UUID) async {
        guard !demo, context == contextID, let coordinator, let epoch = state?.epoch else { return }
        let token = request
        let state = await coordinator.edit(value, expectedEpoch: epoch)
        guard token == request, !demo else { return }
        apply(state)
        if state.enabled && state.phase == .pending && !working { await synchronize() }
    }
    func accountChanged() {
        request += 1; working = false; state = nil; contextID = UUID()
        Task {
            await coordinator?.invalidate()
            await checkAccount()
        }
    }
    func setDemo(_ enabled: Bool) {
        demo = enabled; request += 1; working = false; contextID = UUID()
        Task {
            await coordinator?.invalidate()
            if !enabled { await checkAccount() }
        }
    }
}
