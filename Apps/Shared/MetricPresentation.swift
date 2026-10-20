import SwiftUI
import WristlabCore

let wristMint = Color(red: 0.55, green: 0.96, blue: 0.73)
let wristBackground = Color(red: 0.035, green: 0.055, blue: 0.075)
let wristCard = Color(red: 0.075, green: 0.10, blue: 0.13)

func metricStatus(_ metric: MetricEstimate, at now: Date) -> String {
    if metric.isStale(at: now), metric.value != nil { return "数据已过期" }
    if metric.availability == .calibrating { return "校准中 · \(metric.baselineDays)/14 天" }
    if metric.value == nil { return reasonText(metric.reasons.first ?? "noReadableSamples") }
    return metric.quality == .partial ? "部分数据估算" : "基于个人历史"
}
func reasonText(_ code: String) -> String {
    ["noReadableSamples": "暂无可读取记录", "missingCurrentHRV": "等待 HRV 记录", "missingCurrentRHR": "等待今日静息心率", "missingPrimarySleep": "等待完整主睡眠", "baselineNotReady": "个人基线校准中", "hrOnly": "仅依据心率估算", "missingHR": "等待心率记录", "lowCoverage": "数据覆盖不足", "observationGap": "存在未观测时段", "recalibrationRequired": "等待重新校准", "missingMaximumHR": "请先设置最大心率", "missingHistory": "历史记录不足", "sourceConflict": "部分记录存在冲突", "awaitingSync": "等待手机同步", "stale": "数据已过期", "aboveConfiguredMaximum": "心率超过已设最大值"][code] ?? "等待更多记录"
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
                Text(metric.value.map(String.init) ?? "—").font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                Text("/100").font(.caption).foregroundStyle(.secondary)
            }
            Text(metricStatus(metric, at: now)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
