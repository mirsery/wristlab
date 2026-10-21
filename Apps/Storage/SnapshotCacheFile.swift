import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// Apple file APIs stay in the adapter, outside the scoring package.
enum SnapshotCacheFile {
    static func write(_ data: Data, to destination: URL,
                      prepare: (URL) throws -> Void = excludeFromBackup,
                      commit: (URL, URL) throws -> Void = atomicRename) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".snapshot-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: staging) }
        #if os(iOS) || os(watchOS)
        try data.write(to: staging, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: staging, options: .atomic)
        #endif
        try prepare(staging)
        // Same-directory POSIX rename atomically replaces the file and keeps the
        // prepared file's metadata. No shared-container root attributes change.
        try commit(staging, destination)
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var file = url
        var policy = URLResourceValues(); policy.isExcludedFromBackup = true
        try file.setResourceValues(policy)
    }

    private static func atomicRename(_ source: URL, _ destination: URL) throws {
        let result = source.withUnsafeFileSystemRepresentation { from in
            destination.withUnsafeFileSystemRepresentation { to in rename(from!, to!) }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
