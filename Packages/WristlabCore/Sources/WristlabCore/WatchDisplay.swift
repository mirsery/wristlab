import Foundation

public enum WatchReportMode: String, Codable, CaseIterable, Sendable {
    case phone, local
    public var title: String { self == .local ? "手表本地计算" : "手机同步" }
}

public enum WatchLocalReadState: String, Codable, Sendable {
    case notConnected, enabled, stopped
}

public struct WatchDisplayEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public private(set) var mode: WatchReportMode?
    public private(set) var snapshot: DisplaySnapshot?
    public private(set) var localState: WatchLocalReadState = .notConnected
    public private(set) var cleanupPending = false
    public private(set) var generation = 0
    public private(set) var careProjection: WatchCareProjection?
    public var originTitle: String { mode?.title ?? "请选择报告来源" }

    public static func migrate(phone: DisplaySnapshot?) throws -> Self {
        let value = Self(mode: phone == nil ? nil : .phone, snapshot: phone)
        try value.validate()
        return value
    }
    public func validate() throws {
        guard schemaVersion == 1, generation >= 0,
              mode != nil || snapshot == nil,
              !cleanupPending || localState == .stopped,
              mode != .local || localState == .enabled || snapshot == nil else { throw DomainError.invalidSnapshot }
        if let snapshot {
            try snapshot.validate()
            guard snapshot.source == .healthKit else { throw DomainError.invalidSnapshot }
        }
        try careProjection?.validate()
        guard !cleanupPending || careProjection == nil,
              careProjection?.context == nil || (mode == .local && careProjection?.context?.matches(snapshot) == true) else { throw DomainError.invalidSnapshot }
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 40000 else { throw DomainError.invalidSnapshot }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate()
        return value
    }
    private func advancing() throws -> Self {
        guard generation < Int.max else { throw DomainError.invalidSnapshot }
        var next = self
        next.generation += 1
        return next
    }
    public func selecting(_ mode: WatchReportMode, snapshot: DisplaySnapshot?) throws -> Self {
        var next = try advancing()
        next.mode = mode
        next.snapshot = snapshot
        next.careProjection?.context = nil
        try next.validate()
        return next
    }
    public func projecting(_ snapshot: DisplaySnapshot?, from mode: WatchReportMode) throws -> Self {
        guard self.mode == mode else { return self }
        guard mode != .local || localState == .enabled else { throw DomainError.invalidSnapshot }
        var next = self
        next.snapshot = snapshot
        if next.careProjection?.context?.matches(snapshot) != true { next.careProjection?.context = nil }
        try next.validate()
        return next
    }
    public func enablingLocal() throws -> Self {
        guard !cleanupPending else { throw DomainError.invalidSnapshot }
        var next = try advancing()
        next.localState = .enabled
        try next.validate()
        return next
    }
    public func stoppingLocal() throws -> Self {
        var next = try advancing()
        next.localState = .stopped
        next.cleanupPending = true
        next.careProjection = nil
        if mode == .local { next.snapshot = nil }
        try next.validate()
        return next
    }
    public func finishingCleanup() throws -> Self {
        guard localState == .stopped else { throw DomainError.invalidSnapshot }
        var next = self
        next.cleanupPending = false
        try next.validate()
        return next
    }
    public func updatingCare(_ value: WatchCareProjection?) throws -> Self {
        var next = try advancing()
        next.careProjection = value
        if mode != .local || next.careProjection?.context?.matches(snapshot) != true { next.careProjection?.context = nil }
        try next.validate()
        return next
    }
}

@MainActor public protocol WatchHealthReading {
    func authorize() async throws
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch
    func cancel()
}

public enum WatchDisplayCache {
    public static func read(displayData: Data?, legacyPhoneData: Data?) -> WatchDisplayEnvelope? {
        if let displayData { return try? WatchDisplayEnvelope.decode(displayData) }
        return try? WatchDisplayEnvelope.migrate(phone: ComplicationCache.snapshot(from: legacyPhoneData))
    }
}
