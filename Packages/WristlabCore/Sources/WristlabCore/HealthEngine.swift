import Foundation

public struct DayOverview: Codable, Equatable, Sendable, Identifiable {
    public var day: Date
    public var readiness: Int?
    public var sleepMinutes: Double?
    public var load: Double?
    public var id: Date { day }
}
public struct HealthReport: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var modelVersion = Physiology.version
    public var configurationVersion: Int
    public var inputRevision: Int
    public var day: Date
    public var timeZoneID: String
    public var asOf: Date
    public var source: DataSource
    public var sourceSignature: String
    public var readiness: MetricEstimate
    public var stress: MetricEstimate
    public var stressTimeline: [StressBucket]
    public var energy: EnergyReport
    public var sleep: SleepReport
    public var sleepDebtMinutes: Double?
    public var regularityMinutes: Double?
    public var activity: ActivityReport
    public var history: [DayOverview]
}

public enum HealthEngine {
    private struct Basis {
        var day: Date
        var sleep: SleepReport
        var night: PhysiologyPair?
        var fallback: PhysiologyPair?
        var awake: PhysiologyPair?
        var sleeping: PhysiologyPair?
    }
    public static func evaluate(records input: [HealthRecord], profile: HealthProfile, asOf: Date,
                                inputRevision: Int, source: DataSource = .healthKit) throws -> HealthReport {
        try profile.validate()
        guard asOf.timeIntervalSince1970.isFinite else { throw DomainError.invalidConfiguration }
        let clock = try AnalysisClock(timeZoneID: profile.timeZoneID)
        let today = clock.day(containing: asOf).start
        let records = RecordNormalizer.normalize(input, asOf: asOf)
        let sourceWindow = DateInterval(start: clock.shiftedDay(today, by: -60), end: asOf)
        let hr = RecordNormalizer.selected(records, kind: .heartRate, profile: profile, sourceWindow: sourceWindow)
        let rhr = RecordNormalizer.selected(records, kind: .restingHeartRate, profile: profile, sourceWindow: sourceWindow)
        let hrv = RecordNormalizer.selected(records, kind: .hrv, profile: profile, sourceWindow: sourceWindow)
        let workouts = ActivityCalculator.deduplicatedWorkouts(records, preferredSources: profile.preferredSources[.workout] ?? [])
        let excluded = union(workouts.map { DateInterval(start: $0.start.addingTimeInterval(-1800), end: $0.end.addingTimeInterval(1800)) })
        let usableHRV = hrv.filter { record in !excluded.contains { interval in
            contains(interval, record.end) || intersection(interval, record.interval) != nil
        } }
        var sleeps: [Date: SleepReport] = [:]
        for offset in -60...1 {
            let day = clock.shiftedDay(today, by: offset)
            sleeps[day] = SleepCalculator.report(day: day, records: records, profile: profile, clock: clock, asOf: asOf)
        }
        let asleep = union(sleeps.values.flatMap(\.asleepIntervals))
        let hrByBucket = Dictionary(grouping: hr, by: { bucketStart($0.end) })
        func inSleep(_ at: Date) -> Bool { asleep.contains { contains($0, at) } }
        var basis: [Basis] = []
        for offset in -60...0 {
            let day = clock.shiftedDay(today, by: offset), window = clock.day(containing: day), sleep = sleeps[day]!
            let dayRHR = rhr.filter { contains(window, $0.start) }.sorted(by: rhrOrder).first?.value
            let nightHRV = sleep.primary.map { primary in usableHRV.filter { record in primary.segments.contains { contains($0.interval, record.end) } } } ?? []
            let dayHRV = usableHRV.filter { contains(window, $0.end) }
            let awakeHR = hr.filter { contains(window, $0.end) && !inSleep($0.end) }
            let cleanAwakeHR = awakeHR.filter { record in !excluded.contains { contains($0, record.end) } }
            let awakeGroups = Dictionary(grouping: cleanAwakeHR, by: { bucketStart($0.end) })
            let awakeHRV = dayHRV.filter { !inSleep($0.end) }
            let sleepHR = sleep.primary.map { primary in hr.filter { record in primary.segments.contains { contains($0.interval, record.end) } } } ?? []
            let sleepGroups = Dictionary(grouping: sleepHR, by: { bucketStart($0.end) })
            let span = (cleanAwakeHR.last?.end.timeIntervalSince(cleanAwakeHR.first?.end ?? day)) ?? 0
            let awakePair = awakeGroups.count >= 12 && span >= 14400 ? pair(hrv: awakeHRV, heart: median(awakeGroups.values.compactMap { median($0.compactMap(\.value)) })) : nil
            basis.append(Basis(day: day, sleep: sleep,
                               night: nightHRV.count >= 2 ? pair(hrv: nightHRV, heart: dayRHR) : nil,
                               fallback: pair(hrv: dayHRV, heart: dayRHR), awake: awakePair,
                               sleeping: sleepGroups.count >= 12 && nightHRV.count >= 2 ? pair(hrv: nightHRV, heart: median(sleepGroups.values.compactMap { median($0.compactMap(\.value)) })) : nil))
        }
        func previous(_ day: Date, sleepSource: String? = nil) -> [Basis] {
            let start = clock.shiftedDay(day, by: -60)
            return basis.filter { $0.day >= start && $0.day < day && (sleepSource == nil || $0.sleep.sourceGroup == sleepSource) }
        }
        func readiness(_ row: Basis) -> MetricEstimate {
            let nightMode = row.sleep.primary.map { primary in
                usableHRV.filter { r in primary.segments.contains { contains($0.interval, r.end) } }.count >= 2
            } ?? false
            let value = nightMode ? row.night : row.fallback
            let history = previous(row.day, sleepSource: nightMode ? row.sleep.sourceGroup : nil).compactMap { nightMode ? $0.night : $0.fallback }
            var metric = Physiology.readiness(hrv: value?.hrv, rhr: value?.heartRate, history: history, mode: nightMode ? "night" : "dayFallback")
            if value == nil {
                let currentRHR = rhr.contains { contains(clock.day(containing: row.day), $0.start) }
                if !currentRHR { metric.reasons = ["missingCurrentRHR"] }
            }
            let sampleTimes = rhr.filter { contains(clock.day(containing: row.day), $0.start) }.map(\.end)
                + usableHRV.filter { record in
                    nightMode ? row.sleep.primary?.segments.contains(where: { contains($0.interval, record.end) }) == true : contains(clock.day(containing: row.day), record.end)
                }.map(\.end)
            metric.effectiveAt = sampleTimes.max()
            metric.validUntil = clock.day(containing: row.day).end
            return metric
        }
        var timeline: [StressBucket] = []
        for start in hrByBucket.keys.sorted() where start >= clock.shiftedDay(today, by: -60) {
            let end = start.addingTimeInterval(300)
            guard end <= asOf else { continue }
            let midpoint = start.addingTimeInterval(150), interval = DateInterval(start: start, end: end)
            let activity = workouts.contains { intersection($0.interval, interval) != nil }
            let sleeping = inSleep(midpoint), mode = activity ? "activity" : sleeping ? "sleep" : "awake"
            let day = clock.day(containing: midpoint).start
            let sleepSource = sleeps.values.first { contains($0.window, midpoint) }?.sourceGroup
            let history = previous(day, sleepSource: sleeping && !activity ? sleepSource : nil).compactMap { sleeping && !activity ? $0.sleeping : $0.awake }
            let recent = usableHRV.last { record in record.end < end && end.timeIntervalSince(record.end) <= 10800 && inSleep(record.end) == sleeping }
            var metric = Physiology.stress(hr: median(hrByBucket[start]!.compactMap(\.value)), hrv: recent?.value, history: history, mode: mode)
            let mixed = asleep.contains { intersection($0, interval).map { $0.duration < interval.duration } == true }
            if mixed { metric.quality = .partial; metric.reasons.append("sourceConflict") }
            metric.effectiveAt = end; metric.validUntil = end.addingTimeInterval(900)
            timeline.append(StressBucket(interval: interval, estimate: metric))
        }
        var seeds: [EnergySeed] = []
        var lastSeedFailure: MetricEstimate?
        for row in basis {
            guard let primary = row.sleep.primary else { continue }
            // Diagnose each completed night independently so an older calibration
            // failure cannot hide the latest night's missing inputs.
            lastSeedFailure = MetricEstimate(reasons: ["recalibrationRequired"], mode: "energy")
            let nightHRV = usableHRV.filter { record in primary.segments.contains { contains($0.interval, record.end) } }
            guard nightHRV.count >= 2 else {
                lastSeedFailure = MetricEstimate(reasons: ["missingCurrentHRV"], mode: "energy")
                continue
            }
            let dayRHR = rhr.filter { contains(clock.day(containing: row.day), $0.start) }.sorted { $0.end < $1.end }
            guard !dayRHR.isEmpty else {
                lastSeedFailure = MetricEstimate(reasons: ["missingCurrentRHR"], mode: "energy")
                continue
            }
            for candidate in dayRHR {
                let earliest = max(primary.interval.end.addingTimeInterval(5400), candidate.end)
                let tick = Date(timeIntervalSince1970: ceil(earliest.timeIntervalSince1970 / 60) * 60)
                guard tick <= asOf, tick < clock.day(containing: row.day).end else { continue }
                let history = previous(row.day, sleepSource: row.sleep.sourceGroup).compactMap { past -> PhysiologyPair? in
                    guard let main = past.sleep.primary, main.interval.end.addingTimeInterval(5400) <= tick else { return nil }
                    let values = usableHRV.filter { r in r.end <= tick && main.segments.contains { contains($0.interval, r.end) } }
                    let resting = rhr.filter { $0.end <= tick && contains(clock.day(containing: past.day), $0.start) }.sorted(by: rhrOrder).first?.value
                    return values.count >= 2 ? pair(hrv: values, heart: resting) : nil
                }
                let score = Physiology.readiness(hrv: median(nightHRV.filter { $0.end <= tick }.compactMap(\.value)), rhr: candidate.value, history: history)
                if let raw = score.rawValue { seeds.append(EnergySeed(at: tick, value: raw)); break }
                lastSeedFailure = score
            }
        }
        var energy = EnergyCalculator.replay(seeds: seeds, asleep: asleep, workouts: workouts.map(\.interval), stress: timeline, asOf: asOf)
        if seeds.isEmpty {
            if var failure = lastSeedFailure {
                failure.mode = "energy"
                energy.estimate = failure
            } else {
                energy.estimate = MetricEstimate(reasons: ["missingPrimarySleep"], mode: "energy")
            }
        }
        energy.points = energy.points.filter { $0.at >= today }
        var loads: [Date: LoadSummary] = [:]
        for row in basis {
            let window = clock.day(containing: row.day)
            let resting = restingReference(day: row.day, rhr: rhr, clock: clock)
            var bounds = [window.start, window.end]
            bounds += asleep.compactMap { intersection($0, window) }.flatMap { [$0.start, $0.end] }
            bounds += workouts.compactMap { intersection($0.interval, window) }.flatMap { [$0.start, $0.end] }
            bounds = Set(bounds).sorted()
            let awakeWindows = zip(bounds, bounds.dropFirst()).compactMap { a, b -> DateInterval? in
                let middle = a.addingTimeInterval(b.timeIntervalSince(a) / 2)
                let active = workouts.contains { contains($0.interval, middle) }
                return active || !inSleep(middle) ? DateInterval(start: a, end: b) : nil
            }
            // Completeness is based on the sleep timeline overlapping this civil day.
            let hasSleep = sleeps.values.contains { $0.settled && $0.totalMinutes != nil && $0.asleepIntervals.contains { intersection($0, window) != nil } }
            loads[row.day] = ActivityCalculator.load(hr: hr.filter { $0.end >= window.start && $0.end < window.end }, windows: awakeWindows, maximum: profile.maximumHeartRate, resting: resting,
                                                     asOf: min(asOf, window.end), settled: asOf >= window.end && hasSleep)
        }
        let todayRow = basis.last!, todayLoad = loads[today]!, currentReadiness = readiness(todayRow)
        let priorSeven = (-7 ... -1).map { loads[clock.shiftedDay(today, by: $0)].flatMap { $0.complete ? $0.load : nil } }
        let prior42 = (-42 ... -1).map { loads[clock.shiftedDay(today, by: $0)].flatMap { $0.complete ? $0.load : nil } }
        let atl = ActivityCalculator.meanComplete(priorSeven, count: 7), ctl = ActivityCalculator.meanComplete(prior42, count: 42)
        let resting = restingReference(day: today, rhr: rhr, clock: clock)
        var workoutLoads: [String: LoadSummary] = [:]
        for workout in workouts where intersection(workout.interval, clock.day(containing: today)) != nil {
            workoutLoads[workout.id] = ActivityCalculator.load(hr: hr.filter { $0.end >= today && $0.end < clock.day(containing: today).end }, windows: [intersection(workout.interval, clock.day(containing: today))!], maximum: profile.maximumHeartRate, resting: resting, asOf: asOf, settled: true)
        }
        let exertion = MetricEstimate(todayLoad.load.flatMap(ActivityCalculator.exertion), quality: todayLoad.complete ? .complete : .partial,
                                      reasons: todayLoad.coverage < 0.8 ? ["lowCoverage"] : [], mode: "exertion", effectiveAt: hr.last?.end, coverage: todayLoad.coverage)
        let activity = ActivityReport(day: todayLoad, workouts: workoutLoads, exertion: exertion,
                                      target: profile.maximumHeartRate != nil ? ActivityCalculator.target(lastSeven: priorSeven, readiness: currentReadiness.value, mode: profile.trainingMode) : nil,
                                      atl: atl, ctl: ctl, ratio: ctl.flatMap { c in c > 0 ? atl.map { $0 / c } : nil }, reasons: profile.maximumHeartRate == nil ? ["missingMaximumHR"] : resting == nil ? ["baselineNotReady"] : [])
        let settledDay = asOf >= clock.atHour(14, day: today) ? today : clock.shiftedDay(today, by: -1)
        let debtReports = (-6...0).compactMap { sleeps[clock.shiftedDay(settledDay, by: $0)] }
        let regularStarts = debtReports.compactMap { $0.primary?.interval.start }.map {
            Double(clock.calendar.component(.hour, from: $0) * 60 + clock.calendar.component(.minute, from: $0))
        }
        let history = basis.suffix(7).map { row in DayOverview(day: row.day, readiness: readiness(row).value, sleepMinutes: row.sleep.totalMinutes, load: loads[row.day]?.load) }
        let signature = [hr.first?.source.group, rhr.first?.source.group, hrv.first?.source.group, todayRow.sleep.sourceGroup].compactMap { $0 }.joined(separator: "|")
        return HealthReport(configurationVersion: profile.version, inputRevision: inputRevision, day: today, timeZoneID: profile.timeZoneID, asOf: asOf, source: source, sourceSignature: signature,
                            readiness: currentReadiness, stress: timeline.last?.estimate ?? MetricEstimate(reasons: ["missingHR"]),
                            stressTimeline: timeline.filter { $0.interval.start >= today }, energy: energy, sleep: todayRow.sleep,
                            sleepDebtMinutes: SleepCalculator.debt(minutes: debtReports.map(\.totalMinutes), target: Double(profile.sleepTargetMinutes)),
                            regularityMinutes: SleepCalculator.regularity(startClockMinutes: regularStarts), activity: activity, history: history)
    }
    private static func pair(hrv: [HealthRecord], heart: Double?) -> PhysiologyPair? {
        guard let h = median(hrv.compactMap(\.value)), let heart else { return nil }; return PhysiologyPair(hrv: h, heartRate: heart)
    }
    private static func bucketStart(_ date: Date) -> Date { Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 300) * 300) }
    private static func rhrOrder(_ a: HealthRecord, _ b: HealthRecord) -> Bool {
        if a.end != b.end { return a.end > b.end }; if a.start != b.start { return a.start > b.start }; return a.id > b.id
    }
    private static func restingReference(day: Date, rhr: [HealthRecord], clock: AnalysisClock) -> Double? {
        let values = (-14 ... -1).compactMap { offset -> Double? in
            let interval = clock.day(containing: clock.shiftedDay(day, by: offset))
            return rhr.filter { contains(interval, $0.start) }.sorted(by: rhrOrder).first?.value
        }
        return values.count >= 7 ? median(values) : nil
    }
}
