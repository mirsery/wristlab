import Foundation

public struct PhoneCarePresentation: Equatable, Sendable {
    public let kind: ComplicationMetric
    public let title: String
    public let symbol: String
    public let note: String
    public let isCurrent: Bool
    public let energyFraction: Double?

    public var accessibilityLabel: String {
        "\(kind.title)，\(title)，\(note)，查看详情"
    }

    public init(kind: ComplicationMetric, estimate: MetricEstimate, at now: Date) {
        self.kind = kind
        let explanation = MetricExplanation(estimate, at: now)
        isCurrent = explanation.displayValue != nil
        energyFraction = kind == .energy ? explanation.displayValue.map { Double($0) / 100 } : nil
        guard let value = explanation.displayValue else {
            title = explanation.summary
            note = explanation.detail
            if estimate.isStale(at: now) { symbol = "clock" }
            else {
                switch estimate.availability {
                case .calibrating: symbol = "hourglass"
                case .failed: symbol = "arrow.clockwise"
                default: symbol = "questionmark.circle"
                }
            }
            return
        }
        let quality = estimate.reasons.contains("hrOnly") ? "仅心率估算" : explanation.summary
        switch kind {
        case .readiness:
            title = MetricTier.label(for: kind, value: value) ?? explanation.summary
            symbol = value < 33 ? "leaf" : value < 67 ? "leaf.fill" : "sun.max"
            note = "\(quality) · 实验估算，不是运动安全保证。"
        case .stress:
            if estimate.mode == "activity" {
                title = "运动中"
                symbol = "figure.run"
            } else {
                let band = CareMetricPresentation.pressureLevel(value)
                title = ["较低", "常态", "偏高", "较高"][band]
                symbol = ["leaf", "waveform.path", "wind", "waveform.path.ecg"][band]
            }
            note = "\(quality) · 生理反应估算，不代表心理状态。"
        case .energy:
            title = "身体电量估算"
            symbol = "battery.0percent"
            note = "\(quality) · 实验估算，不是实际测得能量。"
        }
    }
}
