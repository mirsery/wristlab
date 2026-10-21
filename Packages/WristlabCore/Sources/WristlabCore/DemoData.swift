import Foundation

public enum DemoData {
    public static let previewDate = Date(timeIntervalSince1970: 1792504800)
    public static func records(asOf: Date) throws -> [HealthRecord] {
        let clock = try AnalysisClock(timeZoneID: "UTC")
        let source = SampleSource(bundle: "wristlab.synthetic", family: "Watch", rank: 0)
        var records: [HealthRecord] = []
        for offset in -22...0 {
            let day = clock.shiftedDay(asOf, by: offset)
            func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
            func quantity(_ kind: HealthKind, _ hour: Double, _ value: Double, _ suffix: String) {
                let t = at(hour)
                records.append(HealthRecord(id: "\(offset)-\(kind)-\(suffix)", kind: kind, start: t, end: t, value: value, source: source))
            }
            let sleepStart = at(-1)
            for (i, phase) in [(SleepStage.core, 2.0), (.deep, 1.5), (.rem, 1.5), (.core, 3.0)].enumerated() {
                let previous = [0.0, 2, 3.5, 5][i]
                records.append(HealthRecord(id: "sleep-\(offset)-\(i)", kind: .sleep, start: sleepStart.addingTimeInterval(previous * 3600), end: sleepStart.addingTimeInterval((previous + phase.1) * 3600), stage: phase.0, source: source))
            }
            records.append(HealthRecord(id: "bed-\(offset)", kind: .sleep, start: at(-1.5), end: at(7.5), stage: .inBed, source: source))
            quantity(.restingHeartRate, 8, offset == 0 ? 54 : 60, "daily")
            for hour in [1.0, 5.0, 12.0] { quantity(.hrv, hour, offset == 0 ? 80 : 60, String(hour)) }
            for minute in stride(from: 0, to: 420, by: 10) { quantity(.heartRate, Double(minute) / 60, 56, "sleep-\(minute)") }
            for minute in stride(from: 510, to: 1380, by: 5) {
                let hr = offset == 0 ? 64 + 3 * sin(Double(minute) / 40) : 66
                quantity(.heartRate, Double(minute) / 60, hr, "awake-\(minute)")
            }
            records.append(HealthRecord(id: "run-\(offset)", kind: .workout, start: at(9), end: at(9.5), workoutType: "Running", source: source))
            for minute in 540..<570 { quantity(.heartRate, Double(minute) / 60, 140, "workout-\(minute)") }
        }
        return records.filter { $0.end <= asOf }
    }
    /// Synthetic mood logs for the demo; never written anywhere.
    public static func moods(asOf: Date = previewDate) -> [MoodEntry] {
        let day = Date(timeIntervalSince1970: floor(asOf.timeIntervalSince1970 / 86400) * 86400)
        return [
            MoodEntry(id: "demo-mood-daily", at: day.addingTimeInterval(-3 * 3600), kind: .dailyMood, valence: 0.5, classification: 6, labels: [8, 24], associations: [5]),
            MoodEntry(id: "demo-mood-run", at: day.addingTimeInterval(9.6 * 3600), kind: .momentaryEmotion, valence: 0.6, classification: 6, labels: [13], associations: [6]),
            MoodEntry(id: "demo-mood-work", at: day.addingTimeInterval(12.7 * 3600), kind: .momentaryEmotion, valence: -0.3, classification: 3, labels: [29, 34], associations: [17]),
        ].filter { $0.at <= asOf }
    }
    public static func report(asOf: Date = previewDate) throws -> HealthReport {
        try HealthEngine.evaluate(records: records(asOf: asOf), profile: HealthProfile(timeZoneID: "UTC", maximumHeartRate: 190), asOf: asOf, inputRevision: 1, source: .demo)
    }
}
