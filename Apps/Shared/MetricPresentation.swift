import SwiftUI
import WristlabCore

let wristMint = Color(red: 0.55, green: 0.96, blue: 0.73)
let wristBackground = Color(red: 0.035, green: 0.055, blue: 0.075)
let wristCard = Color(red: 0.075, green: 0.10, blue: 0.13)

func metricStatus(_ metric: MetricEstimate, at now: Date) -> String {
    MetricExplanation(metric, at: now).summary
}
func reasonText(_ code: String) -> String {
    MetricExplanation.reasonText(code)
}
struct ScoreRing: View {
    let value: Int?
    var color: Color = wristMint
    var size: CGFloat = 110
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: 9)
            Circle().trim(from: 0, to: CGFloat(value ?? 0) / 100)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(value.map(String.init) ?? "—").font(.system(size: size * 0.31, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("/ 100").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\($0) 分，满分 100" } ?? "暂无数据")
    }
}
struct SmallMetricCard: View {
    let title: String
    let symbol: String
    let metric: MetricEstimate
    let color: Color
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(MetricExplanation(metric, at: now).displayValue.map(String.init) ?? "—").font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                Text("/100").font(.caption).foregroundStyle(.secondary)
            }
            Text(metricStatus(metric, at: now)).font(.caption2).foregroundStyle(.secondary)
            if MetricExplanation(metric, at: now).displayValue == nil {
                Text("查看原因与建议 ↗").font(.caption2).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
