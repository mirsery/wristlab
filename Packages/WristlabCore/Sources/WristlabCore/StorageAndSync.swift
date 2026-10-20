import Foundation

public struct DisplaySnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var producerID: String
    public var epoch: Int
    public var sequence: Int
    public var computedAt: Date
    public var asOf: Date
    public var source: DataSource
    public var modelVersion: String
    public var configurationVersion: Int
    public var timeZoneID: String
    public var analysisDay: Date
    public var readiness: MetricEstimate
    public var stress: MetricEstimate
    public var energy: MetricEstimate
    public var exertion: MetricEstimate
    public var sleepMinutes: Double?
    public var clearData = false
    public init(report: HealthReport, producerID: String, epoch: Int, sequence: Int) {
        self.producerID = producerID; self.epoch = epoch; self.sequence = sequence
        computedAt = report.asOf; asOf = report.asOf; source = report.source; modelVersion = report.modelVersion
        configurationVersion = report.configurationVersion; timeZoneID = report.timeZoneID; analysisDay = report.day
        readiness = report.readiness; stress = report.stress; energy = report.energy.estimate; exertion = report.activity.exertion
        sleepMinutes = report.sleep.totalMinutes
        readiness.contributions = [:]; stress.contributions = [:]; energy.contributions = [:]; exertion.contributions = [:]
    }
    public func validate() throws {
        guard schemaVersion == 1, !producerID.isEmpty, epoch >= 0, sequence >= 0,
              computedAt.timeIntervalSince1970.isFinite, asOf.timeIntervalSince1970.isFinite,
              analysisDay.timeIntervalSince1970.isFinite, TimeZone(identifier: timeZoneID) != nil,
              [readiness, stress, energy, exertion].allSatisfy(\.isValid),
              sleepMinutes.map({ $0.isFinite && $0 >= 0 && $0 <= 1500 }) ?? true,
              !clearData || ([readiness, stress, energy, exertion].allSatisfy { $0.rawValue == nil } && sleepMinutes == nil),
              try JSONEncoder().encode(self).count <= 32768 else { throw DomainError.invalidSnapshot }
    }
    public func encoded() throws -> Data { try validate(); return try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 32768 else { throw DomainError.invalidSnapshot }
        let result = try JSONDecoder().decode(Self.self, from: data); try result.validate(); return result
    }
    public func isStale(at date: Date) -> Bool { date.timeIntervalSince(computedAt) > 3600 || computedAt > date }
}
public struct SnapshotReceiver: Codable, Sendable {
    public private(set) var snapshot: DisplaySnapshot?
    public init() {}
    public mutating func accept(_ incoming: DisplaySnapshot, confirmProducer: Bool = false) throws {
        try incoming.validate()
        guard incoming.source == .healthKit else { throw DomainError.invalidSnapshot }
        if let old = snapshot {
            if old.producerID != incoming.producerID {
                guard confirmProducer else { throw DomainError.producerConfirmationRequired }
            } else {
                guard incoming.epoch > old.epoch || (incoming.epoch == old.epoch && incoming.sequence >= old.sequence) else { throw DomainError.staleRevision }
                if incoming.epoch == old.epoch && incoming.sequence == old.sequence {
                    guard incoming == old else { throw DomainError.invalidSnapshot }; return
                }
            }
        } else if !confirmProducer { throw DomainError.producerConfirmationRequired }
        snapshot = incoming
    }
}
public struct RecordBatch: Sendable {
    public var additions: [HealthRecord]
    public var deletions: Set<String>
    public var anchors: [String: Data]
    public var replaceAll: Bool
    public var queryStart: Date?
    public init(additions: [HealthRecord], deletions: Set<String> = [], anchors: [String: Data] = [:], replaceAll: Bool = false, queryStart: Date? = nil) {
        self.additions = additions; self.deletions = deletions; self.anchors = anchors; self.replaceAll = replaceAll; self.queryStart = queryStart
    }
}
public struct RepositoryState: Codable, Sendable {
    public var profile: HealthProfile
    public var records: [HealthRecord] = []
    public var anchors: [String: Data] = [:]
    public var queryStart: Date?
    public var revision = 0
    public var producerID: String = UUID().uuidString
    public var epoch = 0
    public var sequence = 0
    public var readingEnabled = false
    public var report: HealthReport?
    public var snapshot: DisplaySnapshot?
    public init(profile: HealthProfile) { self.profile = profile }
}
public actor HealthRepository {
    private var state: RepositoryState
    private let file: URL
    public init(file: URL, profile: HealthProfile = HealthProfile()) throws {
        self.file = file
        if FileManager.default.fileExists(atPath: file.path) {
            state = try JSONDecoder().decode(RepositoryState.self, from: Data(contentsOf: file))
            try state.profile.validate(); try state.snapshot?.validate()
        } else { try profile.validate(); state = RepositoryState(profile: profile) }
    }
    public func current() -> RepositoryState { state }
    private func commit(_ next: RepositoryState) throws {
        let data = try JSONEncoder().encode(next)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS) || os(watchOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: .atomic)
        #endif
        state = next
    }
    public func apply(_ batch: RecordBatch, asOf: Date, expectedRevision: Int? = nil) throws -> RepositoryState {
        if let expectedRevision, expectedRevision != state.revision { throw DomainError.staleRevision }
        var next = state
        var records = batch.replaceAll ? [:] : Dictionary(uniqueKeysWithValues: next.records.map { ($0.id, $0) })
        for id in batch.deletions { records.removeValue(forKey: id) }
        for r in batch.additions {
            if let old = records[r.id] {
                if old.version > r.version { continue }
                if old.version == r.version && old != r { throw DomainError.requiresFullReload }
            }
            records[r.id] = r
        }
        next.records = RecordNormalizer.normalize(Array(records.values), asOf: asOf)
        let clock = try AnalysisClock(timeZoneID: next.profile.timeZoneID)
        let cutoff = clock.shiftedDay(asOf, by: -150)
        next.records.removeAll { $0.end < cutoff }
        next.revision += 1
        next.report = try HealthEngine.evaluate(records: next.records, profile: next.profile, asOf: asOf, inputRevision: next.revision)
        if batch.replaceAll { next.anchors = [:] }
        next.anchors.merge(batch.anchors) { _, new in new }; next.queryStart = batch.queryStart ?? next.queryStart
        next.sequence += 1; next.readingEnabled = true
        next.snapshot = DisplaySnapshot(report: next.report!, producerID: next.producerID, epoch: next.epoch, sequence: next.sequence)
        if let old = state.snapshot, var candidate = next.snapshot {
            candidate.computedAt = old.computedAt; candidate.asOf = old.asOf; candidate.sequence = old.sequence
            if candidate == old { next.sequence = state.sequence; next.snapshot = old }
        }
        try commit(next); return next
    }
    public func configure(_ profile: HealthProfile, asOf: Date) throws -> RepositoryState {
        try profile.validate()
        var next = state
        var versioned = profile; versioned.version = state.profile.version + 1
        next.profile = versioned; next.epoch += 1; next.sequence = 0; next.revision += 1
        next.anchors = [:]; next.queryStart = nil
        next.report = try HealthEngine.evaluate(records: next.records, profile: versioned, asOf: asOf, inputRevision: next.revision)
        next.snapshot = DisplaySnapshot(report: next.report!, producerID: next.producerID, epoch: next.epoch, sequence: 0)
        try commit(next); return next
    }
    public func clear(stopReading: Bool, asOf: Date) throws -> RepositoryState {
        var next = state; next.epoch += 1; next.sequence = 0; next.revision += 1
        if stopReading { next.records = []; next.anchors = [:]; next.queryStart = nil; next.readingEnabled = false }
        next.report = nil
        let empty = try HealthEngine.evaluate(records: [], profile: next.profile, asOf: asOf, inputRevision: next.revision)
        var tombstone = DisplaySnapshot(report: empty, producerID: next.producerID, epoch: next.epoch, sequence: 0)
        tombstone.clearData = true; next.snapshot = tombstone
        try commit(next); return next
    }
}
