import Foundation

/// One local notification per analysis day, after today's main sleep has completed and only in the
/// morning window. Only states values or reasons already on the dashboard; never advice.
public struct MorningBrief: Equatable, Sendable {
    /// Local analysis-day hours. 14:00 is where today's report stops being provisional (002).
    public static let window = (start: 5, end: 14)
    public let dayKey: String
    public let title: String
    public let body: String

    public static func make(report: HealthReport?, lastSentDay: String?, hideValues: Bool, now: Date) -> MorningBrief? {
        guard let report, report.source == .healthKit, let primary = report.sleep.primary,
              let clock = try? AnalysisClock(timeZoneID: report.timeZoneID),
              clock.day(containing: now).start == report.day,
              now >= clock.atHour(window.start, day: report.day), now < clock.atHour(window.end, day: report.day) else { return nil }
        let dayKey = clock.label(report.day)
        guard dayKey != lastSentDay else { return nil }
        if hideValues {
            return MorningBrief(dayKey: dayKey, title: "Wristlab 晨报", body: "主睡眠已汇总，打开Wristlab查看今天的准备度。")
        }
        let explanation = MetricExplanation(report.readiness, at: now)
        let readiness = explanation.displayValue.map { value in
            var text = "准备度 \(value)" + (MetricTier.label(for: .readiness, value: value).map { " · \($0)" } ?? "")
            if report.readiness.mode == "dayFallback" { text += "（日间估算）" } else if report.readiness.quality == .partial { text += "（部分估算）" }
            return text
        } ?? "准备度：\(explanation.summary)"
        let minutes = Int(primary.asleepMinutes)
        return MorningBrief(dayKey: dayKey, title: "Wristlab 晨报", body: "\(readiness)；主睡眠 \(minutes / 60)小时\(minutes % 60)分")
    }
}
