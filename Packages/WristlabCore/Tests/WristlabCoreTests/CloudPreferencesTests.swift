import Foundation
import Testing
@testable import WristlabCore

@Test func cloudClearLocalRemovesOtherAccountCaches_TC_CLOUD_006() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount()
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.setAccount(.available("synthetic-B"))
    _ = await sync.checkAccount()
    _ = await sync.disable(clearLocal: true)
    await cloud.setAccount(.available("synthetic-A"))
    let state = await sync.checkAccount()
    #expect(state.preferences == InterfacePreferences())
    #expect(!state.enabled)
    #expect(!state.deletionPending)
    #expect(state.lastSuccess == nil)
}

@Test func cloudRetryDeadlineSurvivesReopen_TC_CLOUD_005() async throws {
    let cloud = SyntheticPreferenceCloud()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("preferences.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sync = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await sync.checkAccount()
    let deadline = Date().addingTimeInterval(120)
    await cloud.setRetry(deadline)
    _ = await sync.enable()
    let requests = await cloud.fetches
    let reopened = try PreferenceSyncCoordinator(backend: cloud, file: file)
    let state = await reopened.checkAccount()
    #expect(state.retryNotBefore == deadline)
    _ = await reopened.enable(); _ = await reopened.synchronize()
    #expect(await cloud.fetches == requests)
}

@Test func cloudPreferencesApplyToRealTrendSelection_TC_CLOUD_002() {
    var preferences = InterfacePreferences()
    preferences.section = "weight"; preferences.metric = "nightHRV"
    preferences.healthDays = 30; preferences.movementDays = 30
    var navigation = TrendsNavigationState()
    navigation.apply(preferences)
    #expect(navigation.selected == .weight)
    #expect(navigation.metric(for: .health) == .nightHRV)
    #expect(navigation.length(for: .movement) == 30)
    #expect(navigation.interfacePreferences == preferences)
}

@Test func cloudSaveCallbackCannotUndoLocalDisable_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.pauseNextSave()
    let saving = Task { await sync.synchronize() }
    await cloud.waitUntilPaused()
    let cleared = await sync.disable(clearLocal: true)
    await cloud.resumeFetch()
    let finished = await saving.value
    #expect(finished.epoch == cleared.epoch)
    #expect(finished.preferences == InterfacePreferences())
    #expect(!finished.enabled)
    #expect(finished.lastSuccess == cleared.lastSuccess)
}

@Test func cloudSaveCallbackCannotModifyNewAccount_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.pauseNextSave()
    let saving = Task { await sync.synchronize() }
    await cloud.waitUntilPaused()
    await sync.invalidate()
    await cloud.setAccount(.available("synthetic-B"))
    let switched = await sync.checkAccount()
    await cloud.resumeFetch()
    let finished = await saving.value
    #expect(finished.epoch == switched.epoch)
    #expect(finished.account == .available("synthetic-B"))
    #expect(finished.preferences == InterfacePreferences())
    #expect(await cloud.records["synthetic-B"] == nil)
}

@Test func cloudRestoreDuringNewEditRequiresConfirmation_TC_CLOUD_003() async throws {
    let cloud = SyntheticPreferenceCloud()
    var remote = InterfacePreferences(); remote.healthDays = 30
    await cloud.seed(CloudPreferenceRecord(preferences: remote, version: "synthetic-remote"))
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable()
    await cloud.pauseNextFetch()
    let restoring = Task { await sync.resolve(.cloud) }
    await cloud.waitUntilPaused()
    var local = InterfacePreferences(); local.movementDays = 30
    _ = await sync.edit(local)
    await cloud.resumeFetch()
    let finished = await restoring.value
    #expect(finished.phase == .conflict)
    #expect(finished.preferences == local)
    #expect(await cloud.saves == 0)
}

actor SyntheticPreferenceCloud: PreferenceCloudBackend {
    var identity: PreferenceCloudAccount = .available("synthetic-A")
    var records: [String: CloudPreferenceRecord] = [:]
    var fail = false
    var saves = 0
    var fetches = 0
    var retryUntil: Date?
    var deleteBeforeSave = false
    var pauseFetch = false
    var paused = false
    var release: CheckedContinuation<Void, Never>?
    var pauseSignal: CheckedContinuation<Void, Never>?
    var pauseSave = false
    var breakFileOnSave: URL?
    func account() async throws -> PreferenceCloudAccount { identity }
    func fetch(account: String) async throws -> CloudPreferenceRecord? {
        fetches += 1
        if pauseFetch {
            pauseFetch = false; paused = true; pauseSignal?.resume(); pauseSignal = nil
            await withCheckedContinuation { release = $0 }
        }
        if let retryUntil { throw PreferenceCloudFailure.retryAfter(retryUntil) }
        if fail { throw PreferenceCloudFailure.unavailable }
        return records[account]
    }
    func save(_ record: CloudPreferenceRecord, account: String, expectedVersion: String?) async throws -> CloudPreferenceRecord {
        if pauseSave {
            pauseSave = false; paused = true; pauseSignal?.resume(); pauseSignal = nil
            await withCheckedContinuation { release = $0 }
        }
        if deleteBeforeSave {
            deleteBeforeSave = false
            records[account] = CloudPreferenceRecord(preferences: nil, version: "synthetic-deleted", deleted: true)
        }
        if fail { throw PreferenceCloudFailure.unavailable }
        guard identity == .available(account) else { throw PreferenceCloudFailure.accountChanged }
        guard records[account]?.version == expectedVersion else { throw PreferenceCloudFailure.conflict }
        saves += 1
        var saved = record
        saved.version = "synthetic-v\(saves)"
        records[account] = saved
        if let file = breakFileOnSave {
            breakFileOnSave = nil
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        }
        return saved
    }
    func setAccount(_ value: PreferenceCloudAccount) { identity = value }
    func seed(_ value: CloudPreferenceRecord, account: String = "synthetic-A") { records[account] = value }
    func setFailure(_ value: Bool) { fail = value }
    func raceDeletion() { deleteBeforeSave = true }
    func setRetry(_ date: Date?) { retryUntil = date }
    func pauseNextFetch() { pauseFetch = true; paused = false }
    func waitUntilPaused() async { if !paused { await withCheckedContinuation { pauseSignal = $0 } } }
    func resumeFetch() { release?.resume(); release = nil }
    func pauseNextSave() { pauseSave = true; paused = false }
    func breakStorage(onNextSave file: URL) { breakFileOnSave = file }
}

@Test func cloudSaveDuringNewEditKeepsNewestValuePending_TC_CLOUD_005() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var first = InterfacePreferences(); first.healthDays = 30
    _ = await sync.edit(first)
    await cloud.pauseNextSave()
    let saving = Task { await sync.synchronize() }
    await cloud.waitUntilPaused()
    var newer = first; newer.movementDays = 30
    _ = await sync.edit(newer)
    await cloud.resumeFetch()
    let finished = await saving.value
    #expect(finished.preferences == newer)
    #expect(finished.pending)
    #expect(await cloud.records["synthetic-A"]?.preferences == first)
    #expect((await sync.synchronize()).phase == .synced)
    #expect(await cloud.records["synthetic-A"]?.preferences == newer)
}

@Test func cloudServerSuccessLocalFailureIsNotComplete_TC_CLOUD_005() async throws {
    let cloud = SyntheticPreferenceCloud()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("preferences.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sync = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.breakStorage(onNextSave: file)
    let failed = await sync.synchronize()
    #expect(failed.phase == .failed)
    #expect(failed.pending)
    #expect(failed.preferences == local)
    #expect(await cloud.records["synthetic-A"]?.preferences == local)
}

@Test func cloudUnknownRecordDoesNotOverwriteEitherSide_TC_CLOUD_003() async throws {
    let cloud = SyntheticPreferenceCloud()
    var invalid = CloudPreferenceRecord(preferences: InterfacePreferences(), version: "future")
    invalid.schemaVersion = 2
    await cloud.seed(invalid)
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount()
    let failed = await sync.enable()
    #expect(failed.phase == .failed)
    #expect(failed.preferences == InterfacePreferences())
    #expect(await cloud.saves == 0)
}

@Test func cloudCancelAndOldQueuedEditsCannotEnableOrCrossAccount_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    let initial = await sync.checkAccount()
    _ = await sync.enable()
    #expect(!(await sync.resolve(.cancel)).enabled)
    await cloud.setAccount(.available("synthetic-B"))
    _ = await sync.checkAccount()
    var old = InterfacePreferences(); old.healthDays = 30
    let ignored = await sync.edit(old, expectedEpoch: initial.epoch)
    #expect(ignored.preferences == InterfacePreferences())
    #expect(await cloud.saves == 0)
}

@Test func cloudCompleteRecordEnvelopeHasNoHealthFields_TC_CLOUD_002() throws {
    let value = CloudPreferenceRecord(preferences: InterfacePreferences(), version: "synthetic")
    let encoded = try JSONEncoder().encode(value)
    let fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(Set(fields.keys) == ["schemaVersion", "preferences", "generation", "deleted", "version"])
    #expect(encoded.count < 2048)
}

@Test func cloudDeleteDuringCASConflictPausesRatherThanOffersUpload_TC_CLOUD_006() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.raceDeletion()
    let state = await sync.synchronize()
    #expect(state.phase == .deleted)
    #expect(!state.enabled)
    #expect(!(await sync.resolve(.local)).enabled)
    #expect(await cloud.saves == 1)
}

@Test func cloudRetryAfterBlocksRepeatedRequests_TC_CLOUD_005() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount()
    let deadline = Date().addingTimeInterval(120)
    await cloud.setRetry(deadline)
    let failed = await sync.enable()
    #expect(failed.retryNotBefore == deadline)
    let calls = await cloud.fetches
    _ = await sync.synchronize(); _ = await sync.enable()
    #expect(await cloud.fetches == calls)
}

@Test func cloudLateFetchCannotCrossAccountEpoch_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    await cloud.pauseNextFetch()
    let old = Task { await sync.synchronize() }
    await cloud.waitUntilPaused()
    await sync.invalidate()
    await cloud.setAccount(.available("synthetic-B"))
    let switched = await sync.checkAccount()
    await cloud.resumeFetch()
    let returned = await old.value
    #expect(returned.account == .available("synthetic-B"))
    #expect(returned.epoch == switched.epoch)
    #expect(returned.preferences == InterfacePreferences())
    #expect(!returned.enabled)
}

@Test func cloudDisableWhileFetchSuspendedPreventsUpload_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    await cloud.pauseNextFetch()
    let old = Task { await sync.synchronize() }
    await cloud.waitUntilPaused()
    let disabled = await sync.disable(clearLocal: true)
    await cloud.resumeFetch()
    let returned = await old.value
    #expect(returned.epoch == disabled.epoch)
    #expect(returned.preferences == InterfacePreferences())
    #expect(!returned.enabled)
    #expect(await cloud.saves == 1)
}

@Test func cloudFailedDeletionSurvivesReopenAndRequiresRetry_TC_CLOUD_006() async throws {
    let cloud = SyntheticPreferenceCloud()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("preferences.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sync = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    await cloud.setFailure(true)
    #expect((await sync.deleteCloud()).deletionPending)
    let reopened = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await reopened.checkAccount()
    #expect(!(await reopened.enable()).enabled)
    await cloud.setFailure(false)
    let retried = await reopened.deleteCloud()
    #expect(!retried.deletionPending)
    #expect(retried.phase == .deleted)
}

@Test func cloudCorruptCacheIsPreserved_TC_CLOUD_005() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("preferences.json")
    let corrupt = Data("synthetic-invalid-cache".utf8)
    try corrupt.write(to: file)
    #expect(throws: (any Error).self) { try PreferenceSyncCoordinator(backend: SyntheticPreferenceCloud(), file: file) }
    #expect(try Data(contentsOf: file) == corrupt)
}

@Test func cloudPayloadContainsOnlyInterfaceFields_TC_CLOUD_002() throws {
    let preferences = InterfacePreferences()
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
    #expect(Set(json.keys) == ["section", "metric", "healthDays", "movementDays"])
    var invalid = preferences
    invalid.healthDays = 42
    #expect(throws: DomainError.self) { try invalid.validate() }
}

@Test func cloudFirstEnableReadsBeforeAnyUpload_TC_CLOUD_003() async throws {
    let cloud = SyntheticPreferenceCloud()
    var remote = InterfacePreferences(); remote.healthDays = 30
    await cloud.seed(CloudPreferenceRecord(preferences: remote, version: "remote-1"))
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount()
    let choice = await sync.enable()
    #expect(choice.phase == .choice)
    #expect(await cloud.saves == 0)
    let restored = await sync.resolve(.cloud)
    #expect(restored.preferences == remote)
    #expect(restored.phase == .synced)
}

@Test func cloudSwitchDoesNotCopyPreviousAccount_TC_CLOUD_004() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount()
    var local = InterfacePreferences(); local.movementDays = 30
    _ = await sync.edit(local)
    _ = await sync.enable()
    _ = await sync.resolve(.local)
    await cloud.setAccount(.available("synthetic-B"))
    let switched = await sync.checkAccount()
    #expect(switched.preferences == InterfacePreferences())
    #expect(!switched.enabled)
    #expect(await cloud.records["synthetic-B"] == nil)
}

@Test func cloudOfflineQueueReopensAndRetries_TC_CLOUD_005() async throws {
    let cloud = SyntheticPreferenceCloud()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("preferences.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sync = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    await cloud.setFailure(true)
    var preferences = InterfacePreferences(); preferences.healthDays = 30
    _ = await sync.edit(preferences)
    let failed = await sync.synchronize()
    #expect(failed.pending)
    #expect(failed.phase == .failed)
    let reopened = try PreferenceSyncCoordinator(backend: cloud, file: file)
    _ = await reopened.checkAccount()
    await cloud.setFailure(false)
    let retried = await reopened.synchronize()
    #expect(retried.phase == .synced)
    #expect(retried.preferences == preferences)
}

@Test func cloudConcurrentChangeRequiresChoice_TC_CLOUD_003() async throws {
    let cloud = SyntheticPreferenceCloud()
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    _ = await sync.checkAccount(); _ = await sync.enable(); _ = await sync.resolve(.local)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await sync.edit(local)
    var remote = InterfacePreferences(); remote.movementDays = 30
    await cloud.seed(CloudPreferenceRecord(preferences: remote, version: "other-device"))
    let conflict = await sync.synchronize()
    #expect(conflict.phase == .conflict)
    #expect(conflict.preferences == local)
    #expect(await cloud.saves == 1)
}

@Test func cloudDeletionPreventsOldClientResurrection_TC_CLOUD_006() async throws {
    let cloud = SyntheticPreferenceCloud()
    let first = try PreferenceSyncCoordinator(backend: cloud)
    _ = await first.checkAccount(); _ = await first.enable(); _ = await first.resolve(.local)
    let second = try PreferenceSyncCoordinator(backend: cloud)
    _ = await second.checkAccount(); _ = await second.enable(); _ = await second.resolve(.cloud)
    let deleted = await first.deleteCloud()
    #expect(deleted.phase == .deleted)
    var local = InterfacePreferences(); local.healthDays = 30
    _ = await second.edit(local)
    let observed = await second.synchronize()
    #expect(observed.phase == .deleted)
    #expect(!observed.enabled)
    #expect(await cloud.records["synthetic-A"]?.deleted == true)
}

@Test func cloudUnavailableAccountNeverEnablesSync_TC_CLOUD_001() async throws {
    let cloud = SyntheticPreferenceCloud()
    await cloud.setAccount(.noAccount)
    let sync = try PreferenceSyncCoordinator(backend: cloud)
    let state = await sync.checkAccount()
    #expect(state.account == .noAccount)
    #expect(!(await sync.enable()).enabled)
    #expect(await cloud.saves == 0)
}
