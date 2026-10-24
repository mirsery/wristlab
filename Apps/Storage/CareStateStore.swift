import Foundation
import WristlabCore

public final class CareStateStore {
    public private(set) var state: CareState
    private let file: URL
    private let writer: (Data, URL) throws -> Void
    public init(file: URL, writer: ((Data, URL) throws -> Void)? = nil) throws {
        self.file = file
        self.writer = writer ?? { try SnapshotCacheFile.write($0, to: $1) }
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            guard data.count <= 16384 else { throw DomainError.invalidSnapshot }
            state = try JSONDecoder().decode(CareState.self, from: data)
            try state.validate()
        } else { state = CareState() }
    }
    public func save(_ value: CareState) throws {
        try value.validate()
        let data = try JSONEncoder().encode(value)
        guard data.count <= 16384 else { throw DomainError.invalidSnapshot }
        try writer(data, file)
        state = value
    }
}
