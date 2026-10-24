import SwiftUI
import WristlabCore

struct MetricDetailView: View {
    let kind: ComplicationMetric
    let title: String
    let metric: MetricEstimate
    let report: HealthReport?
    let now: Date
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ScoreRing(value: MetricExplanation(metric, at: now).displayValue)
                        .accessibilityIdentifier("metric.detail.score")
                    Spacer()
                }.padding()
                Text(metricStatus(metric, at: now))
                Text(MetricExplanation(metric, at: now).detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Section("计算依据") {
                LabeledContent("模式", value: ["night": "夜间数据", "dayFallback": "日间回退估算", "awake": "清醒时段", "sleep": "睡眠中", "activity": "运动中",
                                               "energy": "电量重放", "exertion": "心率区间负荷"][metric.mode] ?? "—")
                LabeledContent("有效基线", value: "\(metric.baselineDays) 天")
                if let coverage = metric.coverage { LabeledContent("观测覆盖", value: "\(Int(coverage * 100))%") }
            }
            let rows = MetricContributions.rows(for: kind, estimate: metric, at: now)
            if !rows.isEmpty {
                Section {
                    ForEach(rows, id: \.input) {
                        ContributionRowView(row: $0).accessibilityIdentifier("metric.detail.contribution.\($0.input.rawValue)")
                    }
                } header: { Text("与个人基线比较") } footer: { Text("按模型内标准化后的偏离判断，接近基线表示偏离很小；只描述对该估算的作用，不是医疗或训练建议。") }
            }
            if !metric.reasons.isEmpty { Section("数据说明") { ForEach(metric.reasons, id: \.self) { Text(reasonText($0)) } } }
            Section("估算模型") {
                LabeledContent("来源", value: report.map { $0.source == .demo ? "合成演示记录" : "Apple 健康（已选来源）" } ?? "暂无报告")
                    .accessibilityElement(children: .combine).accessibilityIdentifier("metric.detail.source")
                Text("这是根据个人记录计算的实验估算，不是直接测量，也不是医疗或训练处方。")
                Text(report?.modelVersion ?? Physiology.version).font(.caption)
                if let at = metric.effectiveAt {
                    LabeledContent("数据时间", value: timestamp(at))
                        .accessibilityElement(children: .combine).accessibilityIdentifier("metric.detail.dataTime")
                }
                if let report {
                    LabeledContent("报告更新时间", value: timestamp(report.asOf))
                        .accessibilityElement(children: .combine).accessibilityIdentifier("metric.detail.reportTime")
                }
            }
        }.navigationTitle(title)
    }

    private func timestamp(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.year().month(.twoDigits).day(.twoDigits)
            .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
        style.locale = Locale(identifier: "zh_CN")
        style.timeZone = TimeZone(identifier: report?.timeZoneID ?? "") ?? .current
        return date.formatted(style)
    }
}

private struct ContributionRowView: View {
    let row: ContributionRow
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.title)
                Spacer()
                Text(row.relationText).foregroundStyle(.secondary)
            }
            if let value = row.valueText, let baseline = row.baselineText, let difference = row.differenceText {
                Text("当前 \(value) · 基线 \(baseline) · \(difference)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            if let effect = row.effectText { Text(effect).font(.caption).foregroundStyle(wristMint) }
        }
        .accessibilityElement(children: .combine)
    }
}
