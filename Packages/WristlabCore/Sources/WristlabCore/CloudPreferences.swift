import Foundation

public struct InterfacePreferences: Codable, Equatable, Sendable {
    public var section = "health"
    public var metric = "readiness"
    public var healthDays = 7
    public var movementDays = 7
    public init() {}
    public func validate() throws {
        guard ["health", "movement", "weight"].contains(section),
              ["readiness", "sleep", "nightHRV", "restingHeartRate"].contains(metric),
              [7, 30].contains(healthDays), [7, 30].contains(movementDays) else { throw DomainError.invalidConfiguration }
    }
}

public struct CloudPreferenceRecord: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var preferences: InterfacePreferences?
    public var generation: String
    public var deleted: Bool
    public var version: String?
    public init(preferences: InterfacePreferences?, version: String? = nil, generation: String = UUID().uuidString, deleted: Bool = false) {
        self.preferences = preferences; self.version = version; self.generation = generation; self.deleted = deleted
    }
    public func validate() throws {
        guard schemaVersion == 1, !generation.isEmpty, generation.count <= 100,
              deleted ? preferences == nil : preferences != nil else { throw DomainError.invalidConfiguration }
        try preferences?.validate()
    }
}

public enum PreferenceCloudAccount: Equatable, Sendable {
    case available(String), noAccount, restricted, unknown, unconfigured
    public var title: String {
        switch self {
        case .available: "当前iCloud账户可用"
        case .noAccount: "未登录iCloud"
        case .restricted: "iCloud访问受限"
        case .unknown: "暂无法确认iCloud账户"
        case .unconfigured: "此安装版本未配置iCloud"
        }
    }
}
public enum PreferenceCloudFailure: Error, Sendable {
    case unavailable, conflict, accountChanged, invalidRecord, unconfigured
    case retryAfter(Date)
}
public protocol PreferenceCloudBackend: Sendable {
    func account() async throws -> PreferenceCloudAccount
    func fetch(account: String) async throws -> CloudPreferenceRecord?
    func save(_ record: CloudPreferenceRecord, account: String, expectedVersion: String?) async throws -> CloudPreferenceRecord
}
public enum PreferenceSyncPhase: Sendable {
    case off, checking, choice, syncing, synced, pending, conflict, deleted, failed, paused
    public var title: String {
        switch self {
        case .off: "同步已关闭"
        case .checking: "正在检查账户"
        case .choice: "请选择恢复云端或上传本机偏好"
        case .syncing: "正在同步界面偏好"
        case .synced: "界面偏好已同步"
        case .pending: "本机偏好待上传"
        case .conflict: "云端已有变化，请确认使用哪一份"
        case .deleted: "云端偏好已删除，同步已暂停"
        case .failed: "本次未完成，保留本机偏好"
        case .paused: "同步暂停，等待iCloud账户可用"
        }
    }
}
public enum PreferenceResolution: Sendable { case cloud, local, cancel }
public struct PreferenceSyncSnapshot: Sendable {
    public var epoch: Int
    public var account: PreferenceCloudAccount
    public var preferences: InterfacePreferences
    public var enabled: Bool
    public var pending: Bool
    public var phase: PreferenceSyncPhase
    public var remote: CloudPreferenceRecord?
    public var lastSuccess: Date?
    public var deletionPending: Bool
    public var retryNotBefore: Date?
}
private struct PreferenceAccountCache: Codable {
    var preferences = InterfacePreferences()
    var enabled = false
    var pending = false
    var base: CloudPreferenceRecord?
    var baseKnown = false
    var lastSuccess: Date?
    var deletionPending = false
    var retryNotBefore: Date?
}
private struct PreferenceCacheDocument: Codable {
    var schemaVersion = 1
    var owner: String?
    var accounts: [String: PreferenceAccountCache] = [:]
    var unbound = PreferenceAccountCache()
}

public actor PreferenceSyncCoordinator {
    private let backend: any PreferenceCloudBackend
    private let file: URL?
    private var document: PreferenceCacheDocument
    private var account: PreferenceCloudAccount = .unknown
    private var phase: PreferenceSyncPhase = .off
    private var remote: CloudPreferenceRecord?
    private var epoch = 0
    private var running = false
    public init(backend: any PreferenceCloudBackend, file: URL? = nil) throws {
        self.backend = backend; self.file = file
        if let file, FileManager.default.fileExists(atPath: file.path) {
            document = try JSONDecoder().decode(PreferenceCacheDocument.self, from: Data(contentsOf: file))
            guard document.schemaVersion == 1 else { throw DomainError.invalidConfiguration }
            for cache in Array(document.accounts.values) + [document.unbound] {
                try cache.preferences.validate(); try cache.base?.validate()
            }
        } else { document = PreferenceCacheDocument() }
    }
    private var cache: PreferenceAccountCache { document.owner.flatMap { document.accounts[$0] } ?? document.unbound }
    public func snapshot() -> PreferenceSyncSnapshot {
        PreferenceSyncSnapshot(epoch: epoch, account: account, preferences: cache.preferences, enabled: cache.enabled, pending: cache.pending,
                               phase: phase, remote: remote, lastSuccess: cache.lastSuccess, deletionPending: cache.deletionPending,
                               retryNotBefore: cache.retryNotBefore)
    }
    private func commit(_ candidate: PreferenceCacheDocument) throws {
        if let file {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(candidate)
            #if os(iOS) || os(watchOS)
            var directory = file.deletingLastPathComponent()
            var policy = URLResourceValues(); policy.isExcludedFromBackup = true
            try directory.setResourceValues(policy)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: file, options: .atomic)
            #endif
        }
        document = candidate
    }
    private func update(_ mutation: (inout PreferenceAccountCache) -> Void) throws {
        var candidate = document
        var value = cache; mutation(&value)
        if let owner = candidate.owner { candidate.accounts[owner] = value } else { candidate.unbound = value }
        try commit(candidate)
    }
    public func invalidate() {
        epoch += 1; running = false; remote = nil; account = .unknown; phase = cache.enabled ? .paused : .off
    }
    public func checkAccount() async -> PreferenceSyncSnapshot {
        guard canAttempt else { phase = .failed; return snapshot() }
        let token = epoch
        phase = .checking
        do {
            let result = try await backend.account()
            guard token == epoch else { return snapshot() }
            if case .available(let owner) = result, owner != document.owner {
                var candidate = document
                var value = candidate.accounts[owner] ?? (candidate.owner == nil ? candidate.unbound : PreferenceAccountCache())
                value.enabled = false
                candidate.owner = owner; candidate.accounts[owner] = value
                try commit(candidate)
                epoch += 1; running = false; remote = nil
            }
            account = result
            phase = cache.deletionPending ? .failed : cache.enabled ? (cache.pending ? .pending : .off) : .off
            if case .available = result {} else if cache.enabled { phase = .paused }
        } catch {
            if token == epoch {
                account = .unknown
                handle(error, token: token)
            }
        }
        return snapshot()
    }
    public func edit(_ preferences: InterfacePreferences, expectedEpoch: Int? = nil) -> PreferenceSyncSnapshot {
        guard expectedEpoch.map({ $0 == epoch }) ?? true else { return snapshot() }
        do {
            try preferences.validate()
            guard preferences != cache.preferences else { return snapshot() }
            try update { $0.preferences = preferences; $0.pending = $0.enabled }
            if phase != .choice && phase != .conflict { phase = cache.enabled ? .pending : .off }
        } catch { phase = .failed }
        return snapshot()
    }
    public func disable(clearLocal: Bool = false) -> PreferenceSyncSnapshot {
        epoch += 1; running = false; remote = nil
        do {
            if clearLocal {
                var candidate = PreferenceCacheDocument()
                candidate.owner = document.owner
                if let owner = candidate.owner { candidate.accounts[owner] = PreferenceAccountCache() }
                try commit(candidate)
                phase = .off
                return snapshot()
            }
            try update {
                $0.enabled = false; $0.pending = false; $0.baseKnown = false
            }
            phase = .off
        } catch { phase = .failed }
        return snapshot()
    }
    public func enable() async -> PreferenceSyncSnapshot {
        guard canAttempt, case .available = account, !running, !cache.deletionPending else { return snapshot() }
        do { try update { $0.enabled = true; $0.baseKnown = false }; return await synchronize() }
        catch { phase = .failed; return snapshot() }
    }
    private func verify(_ owner: String, token: Int) async throws {
        guard token == epoch, account == .available(owner) else { throw PreferenceCloudFailure.accountChanged }
        let current = try await backend.account()
        guard token == epoch, current == .available(owner) else { throw PreferenceCloudFailure.accountChanged }
    }
    public func synchronize() async -> PreferenceSyncSnapshot {
        guard canAttempt, cache.enabled, !cache.deletionPending, !running, case .available(let owner) = account,
              owner == document.owner else { return snapshot() }
        if phase == .choice || phase == .conflict { return snapshot() }
        let token = epoch
        running = true; phase = .syncing
        defer { if token == epoch { running = false } }
        do {
            try await verify(owner, token: token)
            let fetched = try await backend.fetch(account: owner)
            try await verify(owner, token: token)
            try fetched?.validate()
            remote = fetched
            if !cache.baseKnown { phase = .choice; return snapshot() }
            if let fetched, fetched.deleted {
                try update { $0.base = fetched; $0.enabled = false; $0.pending = false; $0.baseKnown = false }
                phase = .deleted; return snapshot()
            }
            guard let fetched else { phase = .choice; return snapshot() }
            if fetched.version != cache.base?.version || fetched.generation != cache.base?.generation {
                if cache.pending { phase = .conflict; return snapshot() }
                try update { $0.preferences = fetched.preferences!; $0.base = fetched; $0.lastSuccess = Date() }
                phase = .synced; return snapshot()
            }
            if cache.pending { try await upload(expected: fetched, owner: owner, token: token) }
            else { try update { $0.lastSuccess = Date() }; phase = .synced }
        } catch { handle(error, token: token) }
        return snapshot()
    }
    public func resolve(_ choice: PreferenceResolution) async -> PreferenceSyncSnapshot {
        guard canAttempt, phase == .choice || phase == .conflict, !running, cache.enabled,
              case .available(let owner) = account, owner == document.owner else { return snapshot() }
        if choice == .cancel { return disable() }
        let token = epoch
        let expected = remote
        let localAtStart = cache.preferences
        running = true; phase = .syncing
        defer { if token == epoch { running = false } }
        do {
            try await verify(owner, token: token)
            if choice == .cloud {
                let current = try await backend.fetch(account: owner)
                try await verify(owner, token: token)
                try current?.validate()
                guard cache.preferences == localAtStart else { remote = current; phase = .conflict; return snapshot() }
                guard current == expected else { remote = current; phase = .conflict; return snapshot() }
                guard let current else { phase = .choice; return snapshot() }
                try update {
                    $0.base = current; $0.baseKnown = !current.deleted; $0.pending = false; $0.enabled = !current.deleted
                    if let preferences = current.preferences { $0.preferences = preferences }
                    $0.lastSuccess = Date()
                }
                phase = current.deleted ? .deleted : .synced
            } else { try await upload(expected: expected, owner: owner, token: token) }
        } catch { handle(error, token: token) }
        return snapshot()
    }
    private func upload(expected: CloudPreferenceRecord?, owner: String, token: Int) async throws {
        let preferences = cache.preferences
        let outgoing = CloudPreferenceRecord(preferences: preferences, generation: expected?.deleted == false ? expected!.generation : UUID().uuidString)
        try await verify(owner, token: token)
        let saved: CloudPreferenceRecord
        do { saved = try await backend.save(outgoing, account: owner, expectedVersion: expected?.version) }
        catch PreferenceCloudFailure.conflict {
            let latest = try await backend.fetch(account: owner)
            try await verify(owner, token: token)
            try latest?.validate()
            if let latest, latest.deleted {
                try update { $0.base = latest; $0.enabled = false; $0.pending = false; $0.baseKnown = false }
                remote = latest; phase = .deleted
                return
            }
            remote = latest; phase = .conflict
            return
        }
        try await verify(owner, token: token)
        try saved.validate()
        try update { $0.base = saved; $0.baseKnown = true; $0.pending = $0.preferences != preferences; $0.lastSuccess = Date() }
        remote = saved; phase = cache.pending ? .pending : .synced
    }
    public func deleteCloud() async -> PreferenceSyncSnapshot {
        guard canAttempt, !running, case .available(let owner) = account, owner == document.owner else { return snapshot() }
        epoch += 1
        let token = epoch
        running = true; phase = .syncing; remote = nil
        defer { if token == epoch { running = false } }
        do {
            try update { $0.enabled = false; $0.pending = false; $0.deletionPending = true; $0.baseKnown = false }
            try await verify(owner, token: token)
            let fetched = try await backend.fetch(account: owner)
            try await verify(owner, token: token)
            try fetched?.validate()
            let marker = CloudPreferenceRecord(preferences: nil, deleted: true)
            let saved = try await backend.save(marker, account: owner, expectedVersion: fetched?.version)
            try await verify(owner, token: token)
            try update { $0.base = saved; $0.deletionPending = false; $0.lastSuccess = Date() }
            phase = .deleted
        } catch { handle(error, token: token); if token == epoch { phase = .failed } }
        return snapshot()
    }
    private var canAttempt: Bool { cache.retryNotBefore.map { Date() >= $0 } ?? true }
    private func handle(_ error: Error, token: Int) {
        guard token == epoch else { return }
        switch error {
        case PreferenceCloudFailure.conflict:
            phase = .pending
        case PreferenceCloudFailure.accountChanged:
            invalidate()
        case PreferenceCloudFailure.unconfigured:
            account = .unconfigured; phase = .failed
        case PreferenceCloudFailure.retryAfter(let date):
            if date.timeIntervalSince1970.isFinite { try? update { $0.retryNotBefore = date } }
            phase = .failed
        default: phase = .failed
        }
    }
}
