import Foundation
import Testing
import WristlabCore
@testable import SnapshotStorage

private enum InjectedFailure: Error { case policy, commit }

private func withCache(_ test: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try test(directory.appendingPathComponent("watch-receiver.json"))
}

@Test func refreshDeliveryPersistsClearAndRejectsLateData() throws {
    try withCache { file in
        var snapshot = DisplaySnapshot(report: try DemoData.report(), producerID: "synthetic-refresh", epoch: 1, sequence: 1)
        snapshot.source = .healthKit
        let previous = snapshot
        var receiver = SnapshotReceiver()
        try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: true) {
            try SnapshotCacheFile.write($0, to: file)
        }
        snapshot.epoch = 2
        snapshot.sequence = 0
        snapshot.clearData = true
        snapshot.readiness = MetricEstimate()
        snapshot.energy = MetricEstimate()
        snapshot.stress = MetricEstimate()
        snapshot.exertion = MetricEstimate()
        snapshot.sleepMinutes = nil
        try WatchSnapshotDelivery.accept(snapshot, receiver: &receiver, confirmProducer: false) {
            try SnapshotCacheFile.write($0, to: file)
        }
        var reopened = try JSONDecoder().decode(SnapshotReceiver.self, from: Data(contentsOf: file))
        #expect(reopened.snapshot == snapshot)
        #expect(throws: DomainError.staleRevision) {
            try WatchSnapshotDelivery.accept(previous, receiver: &reopened, confirmProducer: false) {
                try SnapshotCacheFile.write($0, to: file)
            }
        }
        #expect(try JSONDecoder().decode(SnapshotReceiver.self, from: Data(contentsOf: file)).snapshot == snapshot)
    }
}

@Test func snapshotPolicyFailureLeavesPreviousFile() throws {
    try withCache { file in
        let previous = Data("synthetic previous".utf8)
        try previous.write(to: file)
        #expect(throws: InjectedFailure.policy) {
            try SnapshotCacheFile.write(Data("synthetic next".utf8), to: file, prepare: { _ in throw InjectedFailure.policy })
        }
        #expect(try Data(contentsOf: file) == previous)
        #expect(try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path) == [file.lastPathComponent])
    }
}

@Test func snapshotCommitFailureLeavesPreviousFile() throws {
    try withCache { file in
        let previous = Data("synthetic previous".utf8)
        try previous.write(to: file)
        #expect(throws: InjectedFailure.commit) {
            try SnapshotCacheFile.write(Data("synthetic next".utf8), to: file, prepare: { _ in }, commit: { _, _ in throw InjectedFailure.commit })
        }
        #expect(try Data(contentsOf: file) == previous)
        #expect(try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path) == [file.lastPathComponent])
    }
}

@Test func snapshotFilePersistsAndReopensIncludingClear() throws {
    try withCache { file in
        let report = try DemoData.report()
        var snapshot = DisplaySnapshot(report: report, producerID: "synthetic-test", epoch: 0, sequence: 1)
        snapshot.source = .healthKit // Synthetic fixture through the real receiving/cache path.
        var receiver = SnapshotReceiver()
        try receiver.accept(snapshot, confirmProducer: true)
        var preparedOwnFile = false
        try SnapshotCacheFile.write(JSONEncoder().encode(receiver), to: file, prepare: { staging in
            #expect(staging != file)
            #expect(staging.deletingLastPathComponent() == file.deletingLastPathComponent())
            #expect(FileManager.default.fileExists(atPath: staging.path))
            preparedOwnFile = true
        })
        #expect(preparedOwnFile)
        #expect(try JSONDecoder().decode(SnapshotReceiver.self, from: Data(contentsOf: file)).snapshot == snapshot)
        snapshot.epoch += 1; snapshot.sequence = 0; snapshot.clearData = true
        snapshot.readiness = MetricEstimate(); snapshot.energy = MetricEstimate()
        snapshot.stress = MetricEstimate(); snapshot.exertion = MetricEstimate(); snapshot.sleepMinutes = nil
        try receiver.accept(snapshot)
        try SnapshotCacheFile.write(JSONEncoder().encode(receiver), to: file, prepare: { _ in })
        #expect(try JSONDecoder().decode(SnapshotReceiver.self, from: Data(contentsOf: file)).snapshot?.clearData == true)
    }
}

#if canImport(Darwin)
@Test func snapshotDefaultPolicySurvivesAtomicReplacement() throws {
    try withCache { file in
        let parent = file.deletingLastPathComponent()
        let rootPolicy = try parent.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        for text in ["synthetic first", "synthetic replacement"] {
            let data = Data(text.utf8)
            try SnapshotCacheFile.write(data, to: file)
            #expect(try Data(contentsOf: file) == data)
            #expect(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        }
        #expect(try parent.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == rootPolicy)
    }
}
#endif
