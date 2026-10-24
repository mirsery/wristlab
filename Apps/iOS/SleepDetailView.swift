import SwiftUI
import Charts
import WristlabCore

struct SleepDetailView<StatusContent: View>: View {
    let report: HealthReport
    private let statusContent: StatusContent
    init(report: HealthReport, @ViewBuilder statusContent: () -> StatusContent) {
        self.report = report
        self.statusContent = statusContent()
    }
    private var sleep: SleepBreakdown { SleepBreakdown(report.sleep) }
    private func minutes(_ value: Double) -> String { "\(Int(value.rounded())) 分钟" }
    private func duration(_ value: Double) -> String { "\(Int(value) / 60) 小时 \(Int(value) % 60) 分钟" }
    private func clock(_ date: Date) -> String { date.formatted(reportStyle(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits), report.timeZoneID)) }
    private var hourTicks: [Date] {
        guard let first = sleep.lanes.map(\.interval.start).min(), let last = sleep.lanes.map(\.interval.end).max() else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: report.timeZoneID) ?? .current
        let start = calendar.dateInterval(of: .hour, for: first)?.start ?? first
        return stride(from: 0.0, through: last.timeIntervalSince(start), by: 2 * 3600).map { start.addingTimeInterval($0) }
    }
    var body: some View {
        List {
            Section {
                statusContent
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("实际睡眠", value: sleep.totalMinutes.map(duration) ?? "暂无睡眠记录")
                if let primary = report.sleep.primary {
                    LabeledContent("主睡眠") {
                        Text("\(clock(primary.interval.start))–\(clock(primary.interval.end))")
                    }
                }
                if sleep.lanes.isEmpty {
                    Text("没有已完成主睡眠（实际睡眠至少180分钟），不显示阶段时间轴。").font(.caption).foregroundStyle(.secondary)
                } else {
                    Chart(Array(sleep.lanes.enumerated()), id: \.offset) { _, segment in
                        RectangleMark(xStart: .value("开始", segment.interval.start), xEnd: .value("结束", segment.interval.end),
                                      y: .value("阶段", segment.lane.title), height: .ratio(0.7))
                            .foregroundStyle(color(segment.lane))
                    }
                    .chartYScale(domain: SleepLane.allCases.map(\.title))
                    .chartXAxis {
                        AxisMarks(values: hourTicks) { value in
                            AxisValueLabel { if let date = value.as(Date.self) { Text(hourLabel(date, report.timeZoneID)) } }
                            AxisGridLine()
                        }
                    }
                    .frame(height: 160)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("主睡眠阶段时间轴，" + SleepLane.allCases.compactMap { lane in
                        let total = sleep.lanes.filter { $0.lane == lane }.reduce(0) { $0 + $1.interval.duration / 60 }
                        return total > 0 ? "\(lane.title)\(minutes(total))" : nil
                    }.joined(separator: "，"))
                }
            } header: { Text("\(report.day.formatted(reportStyle(.dateTime.month().day(), report.timeZoneID))) · \(report.sleep.settled ? "主睡眠已汇总" : "主睡眠暂定")") }
            Section {
                if let stages = sleep.stageMinutes, let shares = sleep.stageShares {
                    ForEach([SleepStage.deep, .core, .rem, .unspecified], id: \.self) { stage in
                        if let value = stage == .unspecified ? sleep.unspecifiedMinutes : stages[stage], stage != .unspecified || value > 0 {
                            LabeledContent(SleepLane(stage)?.title ?? "") {
                                Text("\(minutes(value)) · \(Int(((shares[stage] ?? 0) * 100).rounded()))%").monospacedDigit()
                            }
                        }
                    }
                } else {
                    Text(sleep.totalMinutes == nil ? "没有可汇总的睡眠记录。" : "记录没有具体阶段，只显示时长；不会把未测得的阶段算作0。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let unspecified = sleep.unspecifiedMinutes { LabeledContent("未细分", value: minutes(unspecified)) }
                }
            } header: { Text("阶段") }
            Section {
                LabeledContent("效率", value: sleep.efficiency.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                LabeledContent("入睡用时", value: sleep.latencyMinutes.map(minutes) ?? "—")
                LabeledContent("已记录清醒", value: sleep.awakeMinutes.map { "\(minutes($0)) · \(sleep.awakenings ?? 0) 次" } ?? "—")
            } header: { Text("指标") } footer: {
                Text("“—”表示缺少卧床时段或阶段分类不足，无法计算；已记录清醒只统计明确标为清醒的时段。")
            }
            Section("近期睡眠") {
                LabeledContent("7日睡眠债", value: report.sleepDebtMinutes.map { "\(Int($0.rounded())) 分钟" } ?? "有效记录不足")
                LabeledContent("入睡时间偏差", value: report.regularityMinutes.map { "\(Int($0.rounded())) 分钟" } ?? "有效记录不足")
                Text("睡眠债按个人睡眠目标计算；入睡时间偏差描述记录规律，不是医学评估。").font(.caption).foregroundStyle(.secondary)
            }
            Section("小睡") {
                if sleep.naps.isEmpty { Text("无").foregroundStyle(.secondary) }
                ForEach(Array(sleep.naps.enumerated()), id: \.offset) { _, nap in
                    LabeledContent("\(clock(nap.interval.start))–\(clock(nap.interval.end))",
                                   value: minutes(nap.asleepMinutes))
                }
            }
            Section {
                Text("阶段来自已选来源的睡眠记录，未知阶段单列，不归入其他类别。睡眠统计是记录汇总，不是医疗评估。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("睡眠")
    }
    private func color(_ lane: SleepLane) -> Color {
        switch lane {
        case .awake: .orange
        case .rem: .pink
        case .core: .indigo
        case .deep: .purple
        case .unspecified: .gray
        case .unknown: .gray.opacity(0.5)
        }
    }
}
