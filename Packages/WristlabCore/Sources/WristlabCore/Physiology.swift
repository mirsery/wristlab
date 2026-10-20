import Foundation

public struct PhysiologyPair: Codable, Sendable {
    public var hrv: Double
    public var heartRate: Double
    public init(hrv: Double, heartRate: Double) { self.hrv = hrv; self.heartRate = heartRate }
}
public enum Physiology {
    public static let version = "wristlab-physiology-v1"
    static func distribution(_ values: [Double], floor: Double) -> (center: Double, scale: Double) {
        let center = median(values)!
        return (center, max(1.4826 * median(values.map { abs($0 - center) })!, floor))
    }
    public static func readiness(hrv: Double?, rhr: Double?, history: [PhysiologyPair], mode: String = "night") -> MetricEstimate {
        guard let hrv, hrv.isFinite, hrv > 0 else { return MetricEstimate(reasons: ["missingCurrentHRV"], mode: mode) }
        guard let rhr, rhr.isFinite, rhr > 0 else { return MetricEstimate(reasons: ["missingCurrentRHR"], mode: mode) }
        let valid = history.filter { $0.hrv.isFinite && $0.hrv > 0 && $0.heartRate.isFinite && $0.heartRate > 0 }
        guard valid.count >= 14 else { return MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: valid.count, mode: mode) }
        let h = distribution(valid.map { log($0.hrv) }, floor: 0.1)
        let r = distribution(valid.map(\.heartRate), floor: 3)
        let zh = clamp((log(hrv) - h.center) / h.scale, -3, 3), zr = clamp((r.center - rhr) / r.scale, -3, 3)
        return MetricEstimate(clamp(50 + 15 * (0.7 * zh + 0.3 * zr)), baselineDays: valid.count, mode: mode,
                              contributions: ["hrv": hrv, "rhr": rhr, "baselineHRV": exp(h.center), "baselineRHR": r.center, "zHRV": zh, "zRHR": zr])
    }
    public static func stress(hr: Double?, hrv: Double?, history: [PhysiologyPair], mode: String = "awake") -> MetricEstimate {
        guard let hr, hr.isFinite, hr > 0 else { return MetricEstimate(reasons: ["missingHR"], mode: mode) }
        let valid = history.filter { $0.hrv.isFinite && $0.hrv > 0 && $0.heartRate.isFinite && $0.heartRate > 0 }
        guard valid.count >= 14 else { return MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"], baselineDays: valid.count, mode: mode) }
        let h = distribution(valid.map { log($0.hrv) }, floor: 0.1), r = distribution(valid.map(\.heartRate), floor: 5)
        let zhr = clamp((hr - r.center) / r.scale, -3, 3)
        let hasHRV = mode != "activity" && hrv.map { $0.isFinite && $0 > 0 } == true
        let zhrv = hasHRV ? clamp((h.center - log(hrv!)) / h.scale, -3, 3) : 0
        return MetricEstimate(clamp(50 + 15 * (hasHRV ? 0.7 * zhr + 0.3 * zhrv : zhr)),
                              quality: hasHRV ? .complete : .partial, reasons: hasHRV ? [] : ["hrOnly"],
                              baselineDays: valid.count, mode: mode,
                              contributions: ["hr": hr, "baselineHR": r.center, "zHR": zhr, "zHRV": zhrv])
    }
}
