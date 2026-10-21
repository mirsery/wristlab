import Foundation

public enum EnergyContext: Sendable { case asleep, workout, awake(Double) }
public struct EnergySeed: Sendable {
    public var at: Date
    public var value: Double
    public init(at: Date, value: Double) { self.at = at; self.value = value }
}
public struct StressBucket: Codable, Equatable, Sendable {
    public var interval: DateInterval
    public var estimate: MetricEstimate
    public init(interval: DateInterval, estimate: MetricEstimate) { self.interval = interval; self.estimate = estimate }
}
public struct EnergyPoint: Codable, Equatable, Sendable {
    public var at: Date
    public var value: Double?
}
public struct EnergyReport: Codable, Equatable, Sendable {
    public var estimate: MetricEstimate
    public var points: [EnergyPoint]
    /// Replay inputs on the analysis day up to asOf, for display only. nil in reports cached before they existed.
    public var asleepIntervals: [DateInterval]? = nil
    public var workoutIntervals: [DateInterval]? = nil
}
public enum EnergyCalculator {
    public static func step(energy: Double, context: EnergyContext, seconds: Double) -> Double? {
        guard energy.isFinite, (0...100).contains(energy), seconds.isFinite, (0...60).contains(seconds) else { return nil }
        let rate: Double
        switch context {
        case .asleep: rate = 8 * (1 - energy / 100)
        case .workout: rate = -12 * energy / 100
        case .awake(let stress):
            guard stress.isFinite, (0...100).contains(stress) else { return nil }
            rate = stress < 20 ? 2 * (1 - energy / 100) : -(stress < 60 ? 2 : stress < 80 ? 5 : 9) * energy / 100
        }
        return clamp(energy + rate * seconds / 3600)
    }
    public static func replay(seeds: [EnergySeed], asleep: [DateInterval], workouts: [DateInterval], stress: [StressBucket], asOf: Date) -> EnergyReport {
        let seeds = seeds.filter { $0.at <= asOf && $0.value.isFinite && (0...100).contains($0.value) }.sorted { $0.at < $1.at }
        guard let first = seeds.first else { return EnergyReport(estimate: MetricEstimate(reasons: ["missingPrimarySleep", "recalibrationRequired"], mode: "energy"), points: []) }
        let sleep = union(asleep), activity = union(workouts)
        let buckets = stress.filter { $0.interval.end <= asOf && $0.estimate.rawValue != nil }.sorted { $0.interval.start < $1.interval.start }
        var boundaries = [first.at, asOf] + seeds.map(\.at)
        boundaries += (sleep + activity + buckets.map(\.interval)).flatMap { [$0.start, $0.end] }
        var minute = Date(timeIntervalSince1970: floor(first.at.timeIntervalSince1970 / 60) * 60 + 60)
        while minute < asOf { boundaries.append(minute); minute = minute.addingTimeInterval(60) }
        boundaries = Set(boundaries.filter { $0 >= first.at && $0 <= asOf }).sorted()
        var value: Double? = first.value, gap = 0.0, seedAt = first.at, effectiveAt = first.at
        var points = [EnergyPoint(at: first.at, value: first.value)]
        var observed: [DateInterval] = [], partial = false, hasGap = false, seedIndex = 0, bucketIndex = 0
        var sleepIndex = 0, activityIndex = 0
        for (start, end) in zip(boundaries, boundaries.dropFirst()) where start < end {
            while seedIndex + 1 < seeds.count && seeds[seedIndex + 1].at <= start { seedIndex += 1 }
            if value == nil, seeds[seedIndex].at == start {
                value = seeds[seedIndex].value; seedAt = start; gap = 0; observed = []; partial = false; hasGap = false; effectiveAt = start
            }
            while sleepIndex < sleep.count && sleep[sleepIndex].end <= start { sleepIndex += 1 }
            while activityIndex < activity.count && activity[activityIndex].end <= start { activityIndex += 1 }
            while bucketIndex < buckets.count && buckets[bucketIndex].interval.end <= start { bucketIndex += 1 }
            let isWorkout = activityIndex < activity.count && contains(activity[activityIndex], start)
            let isSleep = sleepIndex < sleep.count && contains(sleep[sleepIndex], start)
            let bucket = bucketIndex < buckets.count && contains(buckets[bucketIndex].interval, start) ? buckets[bucketIndex] : nil
            let context: EnergyContext? = isWorkout ? .workout : isSleep ? .asleep : bucket?.estimate.rawValue.map { .awake($0) }
            if let current = value, let context {
                value = step(energy: current, context: context, seconds: end.timeIntervalSince(start))
                observed.append(DateInterval(start: start, end: end)); effectiveAt = end; gap = 0
                partial = partial || bucket?.estimate.quality == .partial || (isWorkout && isSleep)
            } else {
                gap += end.timeIntervalSince(start); hasGap = true
                if gap > 1800 { value = nil }
            }
            points.append(EnergyPoint(at: end, value: context == nil ? nil : value))
        }
        let coverageStart = max(seedAt, asOf.addingTimeInterval(-86400))
        let elapsed = asOf.timeIntervalSince(coverageStart)
        let window = DateInterval(start: coverageStart, end: asOf)
        let covered = observed.compactMap { intersection($0, window) }.reduce(0) { $0 + $1.duration }
        let coverage = elapsed > 0 ? min(1, covered / elapsed) : 1
        var reasons: [String] = []
        if hasGap { reasons.append("observationGap") }
        if value == nil { reasons.append("recalibrationRequired") }
        if coverage < 0.8 { reasons.append("lowCoverage") }
        let estimate = MetricEstimate(coverage >= 0.8 ? value : nil, quality: partial || hasGap ? .partial : .complete,
                                      reasons: reasons, mode: "energy", effectiveAt: effectiveAt,
                                      validUntil: effectiveAt.addingTimeInterval(900), coverage: coverage)
        return EnergyReport(estimate: estimate, points: points)
    }
}
