import SwiftUI
import Charts
import WristlabCore

struct PhoneDashboardView: View {
    @ObservedObject var model: DashboardModel
    @State private var settings = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var report: HealthReport? { model.displayed }
    private var now: Date { model.demoEnabled ? (report?.asOf ?? DemoData.previewDate) : Date() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if model.demoEnabled {
                        HStack {
                            Label("合成演示数据 · 非健康评估", systemImage: "sparkles").font(.caption).foregroundStyle(wristMint)
                            Spacer()
                            Button("退出") { model.demoEnabled = false }.font(.caption)
                        }
                        .padding(12).background(wristMint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    readiness
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricLink("身体电量", "battery.75percent", report?.energy.estimate ?? MetricEstimate(), .cyan)
                        metricLink("生理压力", "waveform.path.ecg", report?.stress ?? MetricEstimate(), .orange)
                    }
                    if let report { energyChart(report); sleepCard(report); weeklyChart(report); activityCard(report) }
                    else { emptyState }
                    Text(model.demoEnabled ? "所有数值由合成记录和同一业务引擎生成。" : model.status)
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    if !model.demoEnabled {
                        Button { Task { await model.enableDemo() } } label: { Label("看看演示", systemImage: "play.circle") }.font(.subheadline)
                    }
                    Text("W R I S T L A B  /  私人状态实验室").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(.secondary).padding(.vertical, 14)
                }
                .padding(.horizontal, 22).padding(.top, 12)
            }
            .background(wristBackground).toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.refresh() }
            .sheet(isPresented: $settings) { SettingsView(model: model) }
        }
        .tint(wristMint)
        .environment(\.timeZone, TimeZone(identifier: report?.timeZoneID ?? model.profile.timeZoneID) ?? .current)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) { Image(systemName: "waveform.path").foregroundStyle(wristMint); Text("WRISTLAB").font(.system(.caption, design: .rounded, weight: .bold)).tracking(3) }
                Spacer()
                Button { settings = true } label: { Image(systemName: "slider.horizontal.3").padding(10).background(wristCard, in: Circle()) }.accessibilityLabel("设置")
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("把状态看清楚。").font(.system(.title, design: .rounded, weight: .bold))
                    Text(now.formatted(.dateTime.month(.wide).day().weekday(.wide))).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.busy { ProgressView() }
                else { Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(wristMint) }
            }
        }
    }
    private var readiness: some View {
        let metric = report?.readiness ?? MetricEstimate(reasons: ["noReadableSamples"])
        return NavigationLink { MetricDetailView(title: "训练准备度", metric: metric, report: report, now: now) } label: {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("训练准备度", systemImage: "leaf.fill").font(.subheadline).foregroundStyle(wristMint)
                    Text(metric.value.map { $0 >= 67 ? "恢复得不错" : $0 >= 33 ? "接近个人常态" : "给自己一点休息" } ?? "从了解自己开始")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(metricStatus(metric, at: now)).font(.caption).foregroundStyle(.secondary)
                    Text("查看依据  ↗").font(.caption2).foregroundStyle(wristMint).padding(.top, 4)
                }
                Spacer(minLength: 0)
                ScoreRing(value: metric.value)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.18), wristCard], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(.plain)
    }
    private func metricLink(_ title: String, _ symbol: String, _ metric: MetricEstimate, _ color: Color) -> some View {
        NavigationLink { MetricDetailView(title: title, metric: metric, report: report, now: now) } label: {
            SmallMetricCard(title: title, symbol: symbol, metric: metric, color: color, now: now)
        }.buttonStyle(.plain)
    }
    private func energyChart(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("一天的节奏").font(.headline); Spacer(); Text("身体电量").font(.caption).foregroundStyle(.cyan) }
            if report.energy.points.contains(where: { $0.value != nil }) {
                Chart(energyPoints(report)) { point in
                    if let value = point.value {
                        LineMark(x: .value("时间", point.at), y: .value("电量", value), series: .value("连续段", point.group)).foregroundStyle(.cyan).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.linear)
                    }
                }
                .chartYScale(domain: 0...100).chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { _ in AxisValueLabel(format: .dateTime.hour()); AxisGridLine().foregroundStyle(.white.opacity(0.04)) } }
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { _ in AxisValueLabel(); AxisGridLine().foregroundStyle(.white.opacity(0.04)) } }
                .frame(height: 100)
            } else { Text("完整睡眠和连续观测就绪后，这里会显示电量变化。缺口不会被补成直线。").font(.caption).foregroundStyle(.secondary).frame(minHeight: 80) }
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private struct ChartPoint: Identifiable { let id: Int; let at: Date; let value: Double?; let group: Int }
    private func energyPoints(_ report: HealthReport) -> [ChartPoint] {
        var group = 0
        return report.energy.points.enumerated().map { index, point in
            if point.value == nil { group += 1 }; return ChartPoint(id: index, at: point.at, value: point.value, group: group)
        }
    }
    private func sleepCard(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("昨晚睡眠", systemImage: "moon.stars.fill").foregroundStyle(.purple); Spacer(); Text(report.sleep.settled ? "已汇总" : "暂定").foregroundStyle(.secondary) }.font(.subheadline)
            Text(report.sleep.totalMinutes.map { "\(Int($0) / 60) 小时 \(Int($0) % 60) 分钟" } ?? "暂无睡眠记录").font(.system(.title2, design: .rounded, weight: .semibold))
            if !report.sleep.stages.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 3) {
                        ForEach([SleepStage.core, .deep, .rem, .unspecified], id: \.self) { phase in
                            if let duration = report.sleep.stages[phase], duration > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(phase == .deep ? Color.purple : phase == .rem ? Color.pink : Color.indigo.opacity(0.8))
                                    .frame(width: max(0, (geometry.size.width - 9) * duration / max(report.sleep.totalMinutes ?? 1, 1)))
                                    .accessibilityLabel("\(phase.rawValue) \(Int(duration)) 分钟")
                            }
                        }
                    }
                }.frame(height: 8)
            }
            HStack { Text("7 日睡眠债"); Spacer(); Text(report.sleepDebtMinutes.map { "\(Int($0)) 分钟" } ?? "记录不足") }.font(.caption).foregroundStyle(.secondary)
            HStack { Text("入睡时间偏差"); Spacer(); Text(report.regularityMinutes.map { "\(Int($0)) 分钟" } ?? "记录不足") }.font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func weeklyChart(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 7 天").font(.headline)
            Chart(report.history) { day in
                if let value = day.readiness { BarMark(x: .value("日期", day.day, unit: .day), y: .value("准备度", value)).foregroundStyle(wristMint.gradient).cornerRadius(4) }
            }.chartYScale(domain: 0...100).frame(height: 110)
            Text("只展示已有记录，缺失日保留空白。").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func activityCard(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("今天的活动", systemImage: "figure.run").font(.headline).foregroundStyle(.orange)
            HStack { Text("体能输出"); Spacer(); Text(report.activity.exertion.value.map { "\($0) / 100" } ?? "暂无数据").monospacedDigit() }
            HStack { Text("已观测负荷"); Spacer(); Text(report.activity.day.load.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") }.font(.subheadline)
            Text(report.activity.reasons.first.map(reasonText) ?? "当日数值为已观测估算，未记录时段不会当成零负荷。").font(.caption).foregroundStyle(.secondary)
            if let target = report.activity.target { Text("历史参考区间 \(Int(target.lower))–\(Int(target.upper))").font(.caption).foregroundStyle(wristMint) }
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("你的数据，留在你的设备。", systemImage: "lock.shield").font(.headline)
            Text("读取心率、HRV、睡眠与运动，建立个人基线。历史不足时会显示校准进度。").font(.subheadline).foregroundStyle(.secondary)
            Button { Task { await model.connect() } } label: { Text("连接 Apple 健康").frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.borderedProminent).disabled(model.busy)
        }.padding(20).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct MetricDetailView: View {
    let title: String
    let metric: MetricEstimate
    let report: HealthReport?
    let now: Date
    private func contributionLabel(_ key: String) -> String {
        ["hrv":"HRV SDNN（ms）", "rhr":"静息心率（bpm）", "hr":"心率（bpm）", "baselineHRV":"个人 HRV 基线（ms）", "baselineRHR":"静息心率基线（bpm）", "baselineHR":"个人心率基线（bpm）"][key] ?? key
    }
    var body: some View {
        List {
            Section { HStack { Spacer(); ScoreRing(value: metric.value); Spacer() }.padding(); Text(metricStatus(metric, at: now)) }
            Section("计算依据") {
                LabeledContent("模式", value: metric.mode == "night" ? "夜间数据" : metric.mode == "dayFallback" ? "日间回退估算" : metric.mode)
                LabeledContent("有效基线", value: "\(metric.baselineDays) 天")
                if let coverage = metric.coverage { LabeledContent("观测覆盖", value: "\(Int(coverage * 100))%") }
                ForEach(metric.contributions.keys.filter { !$0.hasPrefix("z") }.sorted(), id: \.self) { key in
                    LabeledContent(contributionLabel(key), value: metric.contributions[key]!.formatted(.number.precision(.fractionLength(2))))
                }
            }
            if !metric.reasons.isEmpty { Section("数据说明") { ForEach(metric.reasons, id: \.self) { Text(reasonText($0)) } } }
            Section("估算模型") {
                LabeledContent("来源", value: report?.source == .demo ? "合成演示记录" : "Apple 健康（已选来源）")
                Text("这是根据个人记录计算的实验估算，不是直接测量，也不是医疗或训练处方。")
                Text(report?.modelVersion ?? Physiology.version).font(.caption)
                if let at = metric.effectiveAt { LabeledContent("数据时间", value: at.formatted()) }
            }
        }.navigationTitle(title)
    }
}
