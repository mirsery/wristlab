import Foundation
import WidgetKit
import WristlabCore

@MainActor final class WatchHealthAdapter: WatchHealthReading {
    private let reader = HealthKitReader()
    func authorize() async throws { try await reader.authorize() }
    func readBatch(state: RepositoryState, asOf: Date) async throws -> RecordBatch {
        try await reader.readBatch(state: state, asOf: asOf)
    }
    func cancel() { reader.cancelRead() }
}

@MainActor enum WatchRuntime {
    static func makeCareModel(report: WatchReportModel) -> WatchCareModel {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let store = try? CareStateStore(file: base.appendingPathComponent("WristlabLocal/care-state.json"))
        let care = WatchCareModel(reader: DailyActivityReader(), store: store)
        care.canUse = { [weak report] in report?.envelope != nil && report?.envelope?.cleanupPending == false }
        care.publishActivity = { [weak report] value in
            guard let report else { throw DomainError.invalidSnapshot }
            try report.updateActivity(value)
        }
        report.onClearLocal = { [weak care] in
            guard let care else { throw DomainError.invalidSnapshot }
            try care.clearAll()
        }
        return care
    }
    static func makeModel(phone: DisplaySnapshot?) -> WatchReportModel {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mirsery.wristlab.watch")
        let repository = try? HealthRepository(file: base.appendingPathComponent("WristlabLocal/health-state.json"))
        let store = shared.flatMap { try? WatchDisplayStore(file: $0.appendingPathComponent("watch-display-v1.json"), phone: phone) }
        let model = WatchReportModel(reader: WatchHealthAdapter(), repository: repository, store: store, phone: phone)
        model.onDisplayChanged = { WidgetCenter.shared.reloadAllTimelines() }
        return model
    }
}
