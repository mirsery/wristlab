import Foundation

public struct LoadRange: Codable, Equatable, Sendable {
    public var lower: Double
    public var upper: Double
}
public struct LoadSummary: Codable, Equatable, Sendable {
    public var load: Double?
    public var coverage: Double
    public var zoneMinutes: [Double]
    public var intensity: Double?
    public var complete: Bool
    public var aboveMaximum: Bool
}
public struct ActivityReport: Codable, Equatable, Sendable {
    public var day: LoadSummary
    public var workouts: [String: LoadSummary]
    public var exertion: MetricEstimate
    public var target: LoadRange?
    public var atl: Double?
    public var ctl: Double?
    public var ratio: Double?
    public var reasons: [String]
}
public enum ActivityCalculator {
    public static let version = "wristlab-activity-v1"
    public static func zone(hrr: Double) -> Int {
        guard hrr.isFinite else { return 0 }
        for (index, threshold) in [0.5, 0.6, 0.7, 0.8, 0.9].enumerated() where hrr < threshold { return index }
        return 5
    }
    public static func exertion(load: Double) -> Double? {
        guard load.isFinite, load >= 0 else { return nil }; return 100 * (1 - exp(-load / 150))
    }
    public static func target(lastSeven: [Double?], readiness: Int?, mode: TrainingMode) -> LoadRange? {
        guard lastSeven.count == 7, let readiness, (0...100).contains(readiness),
              lastSeven.allSatisfy({ $0.map { $0.isFinite && $0 >= 0 } == true }) else { return nil }
        let base = lastSeven.compactMap { $0 }.reduce(0, +) / 7
        guard base > 0 else { return nil }
        let factors: (Double, Double) = readiness < 33 ? (0.5, 0.8) : readiness < 67 ? (0.8, 1.1) : (1.1, 1.3)
        let modeFactor = mode == .easy ? 0.8 : mode == .build ? 1.1 : 1.0
        return LoadRange(lower: base * factors.0 * modeFactor, upper: base * factors.1 * modeFactor)
    }
    public static func meanComplete(_ values: [Double?], count: Int) -> Double? {
        guard values.count == count, values.allSatisfy({ $0.map { $0.isFinite && $0 >= 0 } == true }) else { return nil }
        return values.compactMap { $0 }.reduce(0, +) / Double(count)
    }
    public static func deduplicatedWorkouts(_ records: [HealthRecord], preferredSources: [String] = []) -> [HealthRecord] {
        let workouts = records.filter { $0.kind == .workout }.sorted { $0.start < $1.start }
        var parent = Array(workouts.indices)
        func root(_ index: Int) -> Int { var x = index; while parent[x] != x { x = parent[x] }; return x }
        for i in workouts.indices {
            for j in workouts.indices where j > i && workouts[i].workoutType == workouts[j].workoutType {
                let a = workouts[i], b = workouts[j]
                let near = abs(a.start.timeIntervalSince(b.start)) <= 60 && abs(a.end.timeIntervalSince(b.end)) <= 60
                let overlap = intersection(a.interval, b.interval)?.duration ?? 0
                if near || overlap / max(a.interval.duration, b.interval.duration) >= 0.9 { parent[root(j)] = root(i) }
            }
        }
        let groups = Dictionary(grouping: workouts.indices, by: { root($0) })
        return groups.values.compactMap { indices in
            indices.map { workouts[$0] }.sorted {
                let left = preferredSources.firstIndex(of: $0.source.group) ?? Int.max
                let right = preferredSources.firstIndex(of: $1.source.group) ?? Int.max
                if left != right { return left < right }
                if $0.source.rank != $1.source.rank { return $0.source.rank < $1.source.rank }
                if $0.start != $1.start { return $0.start < $1.start }; return $0.id < $1.id
            }.first
        }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
    public static func load(hr: [HealthRecord], windows: [DateInterval], maximum: Double?, resting: Double?, asOf: Date, settled: Bool) -> LoadSummary {
        let windows = union(windows)
        let duration = windows.reduce(0) { $0 + $1.duration }
        var empty = LoadSummary(load: nil, coverage: 0, zoneMinutes: Array(repeating: 0, count: 6), intensity: nil, complete: false, aboveMaximum: false)
        guard duration > 0, let maximum, let resting, maximum.isFinite, resting.isFinite,
              (100...240).contains(maximum), maximum > resting + 20 else { return empty }
        let grouped = Dictionary(grouping: hr.filter { $0.kind == .heartRate && $0.valid(asOf: asOf) }, by: \.end)
        let samples = grouped.keys.sorted().map { ($0, median(grouped[$0]!.compactMap(\.value))!) }
        var observed = 0.0, load = 0.0
        for (index, sample) in samples.enumerated() {
            let end = min(sample.0.addingTimeInterval(60), index + 1 < samples.count ? samples[index + 1].0 : asOf, asOf)
            guard sample.0 < end else { continue }
            let interval = DateInterval(start: sample.0, end: end)
            let seconds = windows.compactMap { intersection(interval, $0) }.reduce(0) { $0 + $1.duration }
            let z = zone(hrr: clamp((sample.1 - resting) / (maximum - resting), 0, 1))
            empty.zoneMinutes[z] += seconds / 60; load += Double(z) * seconds / 60; observed += seconds
            if sample.1 > maximum, seconds > 0 { empty.aboveMaximum = true }
        }
        empty.load = observed > 0 ? load : nil; empty.coverage = min(1, observed / duration)
        empty.complete = settled && empty.coverage >= 0.8
        empty.intensity = empty.coverage >= 0.8 && observed > 0 ? 100 * load / (5 * observed / 60) : nil
        return empty
    }
}
