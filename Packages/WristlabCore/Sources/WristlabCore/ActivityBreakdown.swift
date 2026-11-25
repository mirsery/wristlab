import Foundation

public struct ActivityLoadDetail: Equatable, Sendable {
    public let load: Double?
    public let coverage: Double
    public let zoneMinutes: [Double]?
    public let isLowerBound: Bool

    public init(_ summary: LoadSummary) {
        load = summary.load
        coverage = summary.coverage
        zoneMinutes = summary.coverage > 0 && summary.zoneMinutes.contains(where: { $0 > 0 }) ? summary.zoneMinutes : nil
        isLowerBound = summary.load != nil && !summary.complete
    }
}

public struct ActivityWorkoutDetail: Equatable, Sendable, Identifiable {
    public let id: String
    public let number: Int
    public let detail: ActivityLoadDetail
}

public struct ActivityBreakdown: Equatable, Sendable {
    public let day: ActivityLoadDetail
    public let workouts: [ActivityWorkoutDetail]

    public init(_ report: ActivityReport) {
        day = ActivityLoadDetail(report.day)
        workouts = report.workouts.sorted { $0.key < $1.key }.enumerated().map { index, entry in
            ActivityWorkoutDetail(id: entry.key, number: index + 1, detail: ActivityLoadDetail(entry.value))
        }
    }
}
