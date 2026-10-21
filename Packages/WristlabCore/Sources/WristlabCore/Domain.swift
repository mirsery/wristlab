import Foundation

public enum Availability: String, Codable, Sendable { case available, calibrating, insufficientData, unsupported, failed }
public enum DataQuality: String, Codable, Sendable { case complete, partial }
public struct MetricEstimate: Codable, Equatable, Sendable {
    public var rawValue: Double?
    public var availability: Availability
    public var quality: DataQuality
    public var reasons: [String]
    public var baselineDays: Int
    public var mode: String
    public var contributions: [String: Double]
    public var effectiveAt: Date?
    public var validUntil: Date?
    public var coverage: Double?
    public var value: Int? {
        guard let rawValue, rawValue.isFinite, (0...100).contains(rawValue) else { return nil }
        return Int(rawValue.rounded(.toNearestOrAwayFromZero))
    }
    public init(_ rawValue: Double? = nil, availability: Availability = .insufficientData,
                quality: DataQuality = .complete, reasons: [String] = [], baselineDays: Int = 0,
                mode: String = "", contributions: [String: Double] = [:], effectiveAt: Date? = nil,
                validUntil: Date? = nil, coverage: Double? = nil) {
        self.rawValue = rawValue.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
        self.availability = self.rawValue == nil ? (availability == .available ? .insufficientData : availability) : .available
        self.quality = quality; self.reasons = reasons; self.baselineDays = baselineDays
        self.mode = mode; self.contributions = contributions; self.effectiveAt = effectiveAt
        self.validUntil = validUntil; self.coverage = coverage
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rawValue = try values.decodeIfPresent(Double.self, forKey: .rawValue)
        availability = try values.decode(Availability.self, forKey: .availability)
        quality = try values.decode(DataQuality.self, forKey: .quality)
        reasons = try values.decode([String].self, forKey: .reasons)
        baselineDays = try values.decode(Int.self, forKey: .baselineDays)
        mode = try values.decode(String.self, forKey: .mode)
        contributions = try values.decode([String: Double].self, forKey: .contributions)
        effectiveAt = try values.decodeIfPresent(Date.self, forKey: .effectiveAt)
        validUntil = try values.decodeIfPresent(Date.self, forKey: .validUntil)
        coverage = try values.decodeIfPresent(Double.self, forKey: .coverage)
        guard isValid else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid metric estimate")) }
    }
    public func isStale(at now: Date) -> Bool {
        if let effectiveAt, effectiveAt > now { return true }
        return validUntil.map { now > $0 } ?? false
    }
    public var isValid: Bool {
        (rawValue == nil || (rawValue!.isFinite && (0...100).contains(rawValue!))) &&
        ((rawValue != nil) == (availability == .available)) && baselineDays >= 0 &&
        (coverage == nil || (coverage!.isFinite && (0...1).contains(coverage!))) &&
        contributions.values.allSatisfy(\.isFinite)
    }
}

public enum DomainError: Error { case invalidConfiguration, invalidSnapshot, staleRevision, producerConfirmationRequired, requiresFullReload }
public struct AnalysisClock: Sendable {
    public let calendar: Calendar
    public init(timeZoneID: String) throws {
        guard let zone = TimeZone(identifier: timeZoneID) else { throw DomainError.invalidConfiguration }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        self.calendar = calendar
    }
    public func day(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }
    public func shiftedDay(_ date: Date, by days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: day(containing: date).start)!
    }
    public func atHour(_ hour: Int, day date: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day(containing: date).start)!
    }
    public func sleepWindow(day date: Date) -> DateInterval {
        DateInterval(start: atHour(12, day: shiftedDay(date, by: -1)), end: atHour(12, day: date))
    }
    public func label(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

public enum HealthKind: String, Codable, Sendable, CaseIterable { case heartRate, restingHeartRate, hrv, sleep, workout }
public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case inBed, awake, core, deep, rem, unspecified, unknown
    public var isAsleep: Bool { [.core, .deep, .rem, .unspecified].contains(self) }
}
public struct SampleSource: Codable, Equatable, Hashable, Sendable {
    public var bundle: String
    public var family: String
    public var device: String
    public var rank: Int
    public var group: String { bundle + "/" + family }
    public init(bundle: String, family: String, device: String = "", rank: Int = 1) {
        self.bundle = bundle; self.family = family; self.device = device; self.rank = rank
    }
}
public struct HealthRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: HealthKind
    public var start: Date
    public var end: Date
    public var value: Double?
    public var stage: SleepStage?
    public var workoutType: String?
    public var source: SampleSource
    public var manual: Bool
    public var version: Int
    public init(id: String, kind: HealthKind, start: Date, end: Date, value: Double? = nil,
                stage: SleepStage? = nil, workoutType: String? = nil,
                source: SampleSource, manual: Bool = false, version: Int = 0) {
        self.id = id; self.kind = kind; self.start = start; self.end = end; self.value = value
        self.stage = stage; self.workoutType = workoutType; self.source = source; self.manual = manual; self.version = version
    }
    public var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }
    public func valid(asOf: Date) -> Bool {
        guard !id.isEmpty, start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              start <= end, end <= asOf else { return false }
        switch kind {
        case .heartRate, .restingHeartRate: return !manual && value.map { $0.isFinite && $0 > 0 && $0 <= 300 } == true
        case .hrv: return !manual && value.map { $0.isFinite && $0 > 0 && $0 <= 5000 } == true
        case .sleep: return start < end && stage != nil
        case .workout: return start < end
        }
    }
}
public enum TrainingMode: String, Codable, Sendable, CaseIterable { case easy, maintain, build }
public struct HealthProfile: Codable, Equatable, Sendable {
    public var timeZoneID: String
    public var sleepTargetMinutes: Int
    public var maximumHeartRate: Double?
    public var trainingMode: TrainingMode
    public var preferredSources: [HealthKind: [String]]
    public var confirmedNoSleepDays: Set<String>
    public var version: Int
    public init(timeZoneID: String = TimeZone.current.identifier, sleepTargetMinutes: Int = 480,
                maximumHeartRate: Double? = nil, trainingMode: TrainingMode = .maintain,
                preferredSources: [HealthKind: [String]] = [:], confirmedNoSleepDays: Set<String> = [], version: Int = 1) {
        self.timeZoneID = timeZoneID; self.sleepTargetMinutes = sleepTargetMinutes
        self.maximumHeartRate = maximumHeartRate; self.trainingMode = trainingMode
        self.preferredSources = preferredSources; self.confirmedNoSleepDays = confirmedNoSleepDays; self.version = version
    }
    public func validate() throws {
        guard TimeZone(identifier: timeZoneID) != nil, (240...720).contains(sleepTargetMinutes),
              sleepTargetMinutes % 15 == 0, version > 0,
              maximumHeartRate.map({ $0.isFinite && (100...240).contains($0) }) ?? true
        else { throw DomainError.invalidConfiguration }
    }
}

public enum RecordNormalizer {
    public static func normalize(_ records: [HealthRecord], asOf: Date) -> [HealthRecord] {
        var byID: [String: HealthRecord] = [:]
        for record in records.sorted(by: { $0.version == $1.version ? fingerprint($0) < fingerprint($1) : $0.version < $1.version }) where record.valid(asOf: asOf) {
            byID[record.id] = record
        }
        var seen = Set<String>()
        return byID.values.sorted { $0.id < $1.id }.filter { seen.insert(fingerprint($0)).inserted }
            .sorted { $0.end == $1.end ? $0.id < $1.id : $0.end < $1.end }
    }
    static func fingerprint(_ r: HealthRecord) -> String {
        [r.kind.rawValue, r.source.group, r.source.device, String(r.start.timeIntervalSince1970),
         String(r.end.timeIntervalSince1970), r.value.map(String.init(describing:)) ?? "", r.stage?.rawValue ?? "", r.workoutType ?? ""].joined(separator: "|")
    }
    public static func selected(_ records: [HealthRecord], kind: HealthKind, profile: HealthProfile) -> [HealthRecord] {
        let candidates = records.filter { $0.kind == kind }
        let preferences = profile.preferredSources[kind] ?? []
        let ordered = candidates.sorted { a, b in
            let pa = preferences.firstIndex(of: a.source.group) ?? Int.max
            let pb = preferences.firstIndex(of: b.source.group) ?? Int.max
            if pa != pb { return pa < pb }
            if a.source.rank != b.source.rank { return a.source.rank < b.source.rank }
            return a.source.group < b.source.group
        }
        guard let group = ordered.first?.source.group else { return [] }
        return candidates.filter { $0.source.group == group }
    }
}

func median(_ values: [Double]) -> Double? {
    let sorted = values.filter(\.isFinite).sorted(); guard !sorted.isEmpty else { return nil }
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}
func clamp(_ x: Double, _ lower: Double = 0, _ upper: Double = 100) -> Double { min(max(x, lower), upper) }
func contains(_ interval: DateInterval, _ date: Date) -> Bool { interval.start <= date && date < interval.end }
func intersection(_ a: DateInterval, _ b: DateInterval) -> DateInterval? {
    let start = max(a.start, b.start), end = min(a.end, b.end)
    return start < end ? DateInterval(start: start, end: end) : nil
}
func union(_ intervals: [DateInterval]) -> [DateInterval] {
    var result: [DateInterval] = []
    for item in intervals.sorted(by: { $0.start < $1.start }) where item.duration > 0 {
        if let last = result.last, item.start <= last.end { result[result.count - 1] = DateInterval(start: last.start, end: max(item.end, last.end)) }
        else { result.append(item) }
    }
    return result
}
