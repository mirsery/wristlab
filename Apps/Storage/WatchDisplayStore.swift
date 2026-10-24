import Foundation
import WristlabCore

public final class WatchDisplayStore {
    public private(set) var envelope: WatchDisplayEnvelope
    private let file: URL
    private let writer: (Data, URL) throws -> Void
    public init(file: URL, phone: DisplaySnapshot?, writer: ((Data, URL) throws -> Void)? = nil) throws {
        self.file = file
        self.writer = writer ?? { try SnapshotCacheFile.write($0, to: $1) }
        if FileManager.default.fileExists(atPath: file.path) {
            envelope = try WatchDisplayEnvelope.decode(Data(contentsOf: file))
        } else {
            envelope = try WatchDisplayEnvelope.migrate(phone: phone)
            try self.writer(JSONEncoder().encode(envelope), file)
        }
    }
    public func commit(_ value: WatchDisplayEnvelope, persist: ((Data) throws -> Void)? = nil) throws {
        try value.validate()
        guard value.generation >= envelope.generation else { throw DomainError.staleRevision }
        let data = try JSONEncoder().encode(value)
        guard data.count <= 40000 else { throw DomainError.invalidSnapshot }
        if let persist { try persist(data) }
        else { try writer(data, file) }
        envelope = value
    }
}
