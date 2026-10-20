import Foundation

public struct SleepSegment: Codable, Equatable, Sendable {
    public var interval: DateInterval
    public var stage: SleepStage
}
public struct SleepEpisode: Codable, Equatable, Sendable {
    public var interval: DateInterval
    public var asleepMinutes: Double
    public var completed: Bool
    public var segments: [SleepSegment]
}
public struct SleepReport: Codable, Equatable, Sendable {
    public var day: Date
    public var window: DateInterval
    public var sourceGroup: String?
    public var settled: Bool
    public var totalMinutes: Double?
    public var inBedMinutes: Double?
    public var stages: [SleepStage: Double]
    public var efficiency: Double?
    public var latencyMinutes: Double?
    public var awakeMinutes: Double
    public var awakenings: Int
    public var primary: SleepEpisode?
    public var naps: [SleepEpisode]
    public var segments: [SleepSegment]
    public var reasons: [String]
    public var asleepIntervals: [DateInterval] { union(segments.filter { $0.stage.isAsleep }.map(\.interval)) }
}
public enum SleepCalculator {
    public static let version = "wristlab-sleep-v1"
    public static func report(day: Date, records: [HealthRecord], profile: HealthProfile, clock: AnalysisClock, asOf: Date) -> SleepReport {
        let window = clock.sleepWindow(day: day)
        let candidates = records.filter { $0.kind == .sleep && $0.valid(asOf: asOf) && intersection($0.interval, window) != nil }
        let asleepSources = Set(candidates.filter { $0.stage?.isAsleep == true }.map { $0.source.group })
        let selected = RecordNormalizer.selected(candidates.filter { asleepSources.isEmpty || asleepSources.contains($0.source.group) }, kind: .sleep, profile: profile)
        let beds = union(selected.filter { $0.stage == .inBed }.compactMap { intersection($0.interval, window) })
        let staged = selected.filter { $0.stage != .inBed }
        let bounds = Set(staged.flatMap { r -> [Date] in
            guard let i = intersection(r.interval, window) else { return [] }; return [i.start, i.end]
        }).sorted()
        var segments: [SleepSegment] = [], reasons: [String] = []
        for (start, end) in zip(bounds, bounds.dropFirst()) where start < end {
            let middle = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            let phases = Set(staged.filter { contains($0.interval, middle) }.compactMap(\.stage))
            guard !phases.isEmpty else { continue }
            let specific = phases.intersection([.core, .deep, .rem])
            let conflict = specific.count > 1 || (phases.contains(.awake) && phases.contains(where: \.isAsleep))
            let phase: SleepStage = conflict ? .unknown : (specific.first ?? (phases.contains(.awake) ? .awake : phases.contains(.unspecified) ? .unspecified : .unknown))
            if conflict { reasons.append("sourceConflict") }
            segments.append(SleepSegment(interval: DateInterval(start: start, end: end), stage: phase))
        }
        let asleep = segments.filter { $0.stage.isAsleep }
        var groups: [[SleepSegment]] = []
        for segment in asleep {
            if let last = groups.last?.last, segment.interval.start.timeIntervalSince(last.interval.end) <= 5400 {
                groups[groups.count - 1].append(segment)
            } else { groups.append([segment]) }
        }
        let episodes: [SleepEpisode] = groups.compactMap { group in
            let minutes = group.reduce(0) { $0 + $1.interval.duration / 60 }
            guard minutes >= 20 else { return nil }
            let interval = DateInterval(start: group.first!.interval.start, end: group.last!.interval.end)
            return SleepEpisode(interval: interval, asleepMinutes: minutes, completed: asOf.timeIntervalSince(interval.end) >= 5400, segments: group)
        }
        let completed = episodes.filter(\.completed)
        let primary = completed.filter { $0.asleepMinutes >= 180 }.sorted {
            if $0.asleepMinutes != $1.asleepMinutes { return $0.asleepMinutes > $1.asleepMinutes }
            return $0.interval.end > $1.interval.end
        }.first
        let completedSegments = completed.flatMap(\.segments)
        let specificExists = completedSegments.contains { [.core, .deep, .rem].contains($0.stage) }
        var stages: [SleepStage: Double] = [:]
        for phase in [SleepStage.core, .deep, .rem, .unspecified] where specificExists || phase == .unspecified {
            stages[phase] = completedSegments.filter { $0.stage == phase }.reduce(0) { $0 + $1.interval.duration / 60 }
        }
        var efficiency: Double?, latency: Double?
        if let primary {
            let primaryBeds = beds.filter { intersection($0, primary.interval) != nil }
            let bedSeconds = primaryBeds.reduce(0) { $0 + $1.duration }
            let known = segments.filter { $0.stage != .unknown }
            let classifiedSeconds = primaryBeds.reduce(0.0) { sum, bed in
                sum + known.compactMap { intersection($0.interval, bed) }.reduce(0) { $0 + $1.duration }
            }
            let sleepSeconds = primaryBeds.reduce(0.0) { sum, bed in
                sum + asleep.compactMap { intersection($0.interval, bed) }.reduce(0) { $0 + $1.duration }
            }
            if bedSeconds > 0, classifiedSeconds / bedSeconds >= 0.8 {
                efficiency = sleepSeconds / bedSeconds
                if classifiedSeconds < bedSeconds { reasons.append("lowCoverage") }
            }
            if let bed = primaryBeds.first(where: { contains($0, primary.interval.start) }) {
                let prefix = DateInterval(start: bed.start, end: primary.interval.start)
                let awake = union(segments.filter { $0.stage == .awake }.compactMap { intersection($0.interval, prefix) }).reduce(0) { $0 + $1.duration }
                if abs(awake - prefix.duration) < 0.001 { latency = prefix.duration / 60 }
            }
        }
        let awakeIntervals = union(segments.filter { $0.stage == .awake }.map(\.interval))
        let total = completed.isEmpty ? nil : completed.reduce(0) { $0 + $1.asleepMinutes }
        let settled = asOf >= clock.atHour(14, day: day)
        let confirmed = profile.confirmedNoSleepDays.contains(clock.label(day)) && total == nil && settled
        return SleepReport(day: clock.day(containing: day).start, window: window, sourceGroup: selected.first?.source.group,
                           settled: settled, totalMinutes: confirmed ? 0 : total,
                           inBedMinutes: beds.isEmpty ? nil : beds.reduce(0) { $0 + $1.duration / 60 }, stages: stages,
                           efficiency: efficiency, latencyMinutes: latency, awakeMinutes: awakeIntervals.reduce(0) { $0 + $1.duration / 60 },
                           awakenings: awakeIntervals.count, primary: primary, naps: completed.filter { $0.interval != primary?.interval },
                           segments: segments, reasons: Array(Set(reasons)).sorted())
    }
    public static func debt(minutes: [Double?], target: Double) -> Double? {
        guard minutes.count == 7, target.isFinite, target > 0, minutes.allSatisfy({ $0.map { $0.isFinite && $0 >= 0 } == true }) else { return nil }
        return max(0, 7 * target - minutes.compactMap { $0 }.reduce(0, +))
    }
    public static func regularity(startClockMinutes: [Double]) -> Double? {
        guard startClockMinutes.count == 7, startClockMinutes.allSatisfy({ $0.isFinite && (0..<1440).contains($0) }) else { return nil }
        let unwrapped = startClockMinutes.map { ($0 - 720 + 1440).truncatingRemainder(dividingBy: 1440) }
        let center = median(unwrapped)!
        return median(unwrapped.map { abs($0 - center) })
    }
}
