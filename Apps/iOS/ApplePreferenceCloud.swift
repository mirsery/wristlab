import Foundation
@preconcurrency import CloudKit
import WristlabCore

actor ApplePreferenceCloud: PreferenceCloudBackend {
    private let identifier: String?
    private let environment: String
    private var cached: CKRecord?
    private var cachedOwner: String?
    init() {
        identifier = Bundle.main.object(forInfoDictionaryKey: "WristlabCloudKitEnabled") as? Bool == true
            ? Bundle.main.object(forInfoDictionaryKey: "WristlabCloudContainer") as? String : nil
        environment = Bundle.main.object(forInfoDictionaryKey: "WristlabCloudEnvironment") as? String ?? "Unknown"
    }
    private var container: CKContainer? { identifier.map { CKContainer(identifier: $0) } }
    private let recordID = CKRecord.ID(recordName: "InterfacePreferences-v1")
    func account() async throws -> PreferenceCloudAccount {
        #if targetEnvironment(simulator)
        return .unconfigured
        #else
        guard let container, ["Development", "Production"].contains(environment) else { return .unconfigured }
        do {
        switch try await container.accountStatus() {
        case .available:
            let user = try await container.userRecordID()
            return .available(environment + "|" + user.recordName)
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        default: return .unknown
        }
        } catch { throw mapped(error) }
        #endif
    }
    private func verify(_ owner: String) async throws {
        guard try await account() == .available(owner) else { throw PreferenceCloudFailure.accountChanged }
    }
    func fetch(account owner: String) async throws -> CloudPreferenceRecord? {
        try await verify(owner)
        guard let container else { throw PreferenceCloudFailure.unavailable }
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            try await verify(owner)
            let value = try decode(record)
            cached = record; cachedOwner = owner
            return value
        } catch let error as CKError where error.code == .unknownItem {
            cached = nil; cachedOwner = nil
            return nil
        } catch { throw mapped(error) }
    }
    func save(_ value: CloudPreferenceRecord, account owner: String, expectedVersion: String?) async throws -> CloudPreferenceRecord {
        try value.validate()
        try await verify(owner)
        guard let container else { throw PreferenceCloudFailure.unavailable }
        let record: CKRecord
        if let expectedVersion {
            guard cachedOwner == owner, let cached, cached.recordChangeTag == expectedVersion else { throw PreferenceCloudFailure.conflict }
            record = cached.copy() as! CKRecord
        } else { record = CKRecord(recordType: "InterfacePreferences", recordID: recordID) }
        record["schemaVersion"] = NSNumber(value: value.schemaVersion)
        record["generation"] = value.generation as NSString
        record["deleted"] = NSNumber(value: value.deleted)
        record["payload"] = try value.preferences.map { try JSONEncoder().encode($0) } as CKRecordValue?
        do {
            let result = try await container.privateCloudDatabase.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
            let saved = try result.saveResults[recordID]?.get()
            try await verify(owner)
            guard let saved else { throw PreferenceCloudFailure.unavailable }
            let decoded = try decode(saved)
            cached = saved; cachedOwner = owner
            return decoded
        } catch { throw mapped(error) }
    }
    private func mapped(_ error: Error) -> Error {
        guard let error = error as? CKError else { return error }
        if error.code == .serverRecordChanged { return PreferenceCloudFailure.conflict }
        if error.code == .missingEntitlement || error.code == .badContainer { return PreferenceCloudFailure.unconfigured }
        if let seconds = error.retryAfterSeconds, seconds.isFinite, seconds > 0 {
            return PreferenceCloudFailure.retryAfter(Date().addingTimeInterval(seconds))
        }
        return error
    }
    private func decode(_ record: CKRecord) throws -> CloudPreferenceRecord {
        guard record.recordType == "InterfacePreferences",
              Set(record.allKeys()).isSubset(of: ["schemaVersion", "generation", "deleted", "payload"]),
              record["payload"] == nil || record["payload"] is Data,
              let schema = record["schemaVersion"] as? NSNumber, let generation = record["generation"] as? String,
              let deleted = record["deleted"] as? NSNumber else { throw PreferenceCloudFailure.invalidRecord }
        let payload = record["payload"] as? Data
        guard payload.map({ $0.count <= 2048 }) ?? true else { throw PreferenceCloudFailure.invalidRecord }
        var value = CloudPreferenceRecord(preferences: try payload.map { try JSONDecoder().decode(InterfacePreferences.self, from: $0) },
                                          version: record.recordChangeTag, generation: generation, deleted: deleted.boolValue)
        value.schemaVersion = schema.intValue
        try value.validate()
        return value
    }
}
