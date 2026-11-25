import Foundation
@preconcurrency import HealthKit
import WristlabCore

@MainActor final class DailyActivityReader: DailyActivityReading {
    private let store = HKHealthStore()
    private var queries: [UUID: HKQuery] = [:]
    private var cancellations: [UUID: () -> Void] = [:]
    private var timeouts: [UUID: Task<Void, Never>] = [:]
    private var generation = UUID()
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw DomainError.invalidConfiguration }
        try await store.requestAuthorization(toShare: [], read: [HKQuantityType(.stepCount), HKObjectType.activitySummaryType()])
    }
    func cancel() {
        generation = UUID()
        for token in Array(queries.keys) { cancel(token) }
    }
    static func summaryDateComponents(at date: Date, clock: AnalysisClock) -> DateComponents {
        var components = clock.calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.calendar = clock.calendar
        components.timeZone = clock.calendar.timeZone
        return components
    }
    private func cancel(_ token: UUID) {
        if let query = queries.removeValue(forKey: token) { store.stop(query) }
        timeouts.removeValue(forKey: token)?.cancel()
        cancellations.removeValue(forKey: token)?()
    }
    private func execute<Value: Sendable>(_ build: (@escaping @Sendable (Result<Value, any Error>) -> Void) -> HKQuery) async throws -> Value {
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                let query = build { [weak self] result in
                    Task { @MainActor in
                        guard let self, self.queries.removeValue(forKey: token) != nil else { return }
                        self.cancellations.removeValue(forKey: token)
                        self.timeouts.removeValue(forKey: token)?.cancel()
                        continuation.resume(with: result)
                    }
                }
                queries[token] = query
                cancellations[token] = { continuation.resume(throwing: CancellationError()) }
                timeouts[token] = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    self?.cancel(token)
                }
                store.execute(query)
            }
        } onCancel: { Task { @MainActor [weak self] in self?.cancel(token) } }
    }
    func read(at now: Date, timeZoneID: String) async throws -> DailyActivityReport {
        let token = generation
        let clock = try AnalysisClock(timeZoneID: timeZoneID)
        let today = clock.day(containing: now).start
        let start = clock.shiftedDay(today, by: -6)
        var result = DailyActivityReport(timeZoneID: timeZoneID, day: today)
        do {
            result.steps = try await execute { finish in
                let query = HKStatisticsCollectionQuery(quantityType: HKQuantityType(.stepCount),
                    quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: now, options: .strictEndDate),
                    options: .cumulativeSum, anchorDate: today,
                    intervalComponents: DateComponents(calendar: clock.calendar, timeZone: clock.calendar.timeZone, day: 1))
                query.initialResultsHandler = { _, collection, error in
                    if let error { finish(.failure(error)); return }
                    let days = (0..<7).map { offset in
                        let day = clock.shiftedDay(start, by: offset)
                        return DaySteps(day: day, count: collection?.statistics(for: day)?.sumQuantity()?.doubleValue(for: .count()))
                    }
                    finish(.success(days))
                }
                return query
            }
            result.stepsReadAt = now
        } catch { result.stepsFailed = true }
        guard generation == token, !Task.isCancelled else { throw CancellationError() }
        do {
            result.rings = try await execute { finish in
                let components = Self.summaryDateComponents(at: now, clock: clock)
                return HKActivitySummaryQuery(predicate: HKQuery.predicateForActivitySummary(with: components)) { _, summaries, error in
                    if let error { finish(.failure(error)); return }
                    guard let summary = summaries?.first else { finish(.success(nil)); return }
                    let move: ActivityRing
                    switch summary.activityMoveMode {
                    case .activeEnergy: move = ActivityRing(value: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()), goal: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()), unit: "kcal")
                    case .appleMoveTime: move = ActivityRing(value: summary.appleMoveTime.doubleValue(for: .minute()), goal: summary.appleMoveTimeGoal.doubleValue(for: .minute()), unit: "min")
                    @unknown default: move = ActivityRing(value: nil, goal: nil, unit: "min")
                    }
                    let paused: Bool?
                    if #available(watchOS 11, *) { paused = summary.isPaused } else { paused = nil }
                    finish(.success(ActivityRings(move: move,
                        exercise: ActivityRing(value: summary.appleExerciseTime.doubleValue(for: .minute()), goal: summary.exerciseTimeGoal?.doubleValue(for: .minute()), unit: "min"),
                        stand: ActivityRing(value: summary.appleStandHours.doubleValue(for: .count()), goal: summary.standHoursGoal?.doubleValue(for: .count()), unit: "h"), paused: paused)))
                }
            }
            result.ringsReadAt = now
        } catch { result.ringsFailed = true }
        guard generation == token, !Task.isCancelled else { throw CancellationError() }
        return result
    }
}
