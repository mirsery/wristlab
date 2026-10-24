import Foundation

public struct HealthReadBuffer: Sendable {
    private var additions: [HealthRecord] = []
    public private(set) var deletions: Set<String> = []
    private let maximumRecords: Int
    public init(maximumRecords: Int = Int.max) { self.maximumRecords = max(0, maximumRecords) }
    public var recordsForCommit: [HealthRecord] { additions.filter { !deletions.contains($0.id) } }
    public mutating func append(_ records: [HealthRecord], deleted: Set<String>) throws {
        let nextDeleted = deletions.union(deleted)
        guard additions.count <= maximumRecords,
              records.count <= maximumRecords - additions.count,
              nextDeleted.count <= maximumRecords - additions.count - records.count else { throw DomainError.invalidSnapshot }
        additions += records
        deletions = nextDeleted
    }
}

public struct HealthRecordPage: Sendable {
    public let records: [HealthRecord]
    public let deleted: Set<String>
    public let anchor: Data
    public let count: Int
    public init(records: [HealthRecord], deleted: Set<String>, anchor: Data, count: Int) {
        self.records = records; self.deleted = deleted; self.anchor = anchor; self.count = count
    }
}

public enum HealthBatchLoader {
    public static let pageSize = 500
    @MainActor public static func load(
        kinds: [HealthKind], anchors: [String: Data], replaceAll: Bool, queryStart: Date,
        maximumRecords: Int = Int.max,
        isCancelled: () -> Bool = { false },
        fetch: (HealthKind, Data?) async throws -> HealthRecordPage
    ) async throws -> RecordBatch {
        var buffer = HealthReadBuffer(maximumRecords: maximumRecords)
        var finalAnchors: [String: Data] = [:]
        for kind in kinds {
            var anchor = replaceAll ? nil : anchors[kind.rawValue]
            while true {
                try Task.checkCancellation()
                if isCancelled() { throw CancellationError() }
                let page = try await fetch(kind, anchor)
                try Task.checkCancellation()
                if isCancelled() { throw CancellationError() }
                guard (0...pageSize).contains(page.count), !page.anchor.isEmpty,
                      page.count >= page.records.count + page.deleted.count,
                      page.count < pageSize || page.anchor != anchor else { throw DomainError.invalidSnapshot }
                try buffer.append(page.records, deleted: page.deleted)
                finalAnchors[kind.rawValue] = page.anchor
                if page.count < pageSize { break }
                anchor = page.anchor
            }
        }
        return RecordBatch(additions: buffer.recordsForCommit, deletions: buffer.deletions,
            anchors: finalAnchors, replaceAll: replaceAll, queryStart: queryStart)
    }
}
