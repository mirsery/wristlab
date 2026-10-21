import SwiftUI
import Charts
import WristlabCore

struct PhoneDashboardView: View {
    @ObservedObject var model: DashboardModel
    @State private var settings = false
    @State private var trend: TrendMetric = .readiness
    @Environment(\.dynamicTypeSize) private var typeSize
    private var report: HealthReport? { model.displayed }
    private var now: Date { model.demoEnabled ? (report?.asOf ?? DemoData.previewDate) : Date() }
    private var dateLabel: String {
        var format = Date.FormatStyle.dateTime.month(.wide).day().weekday(.wide)
        format.locale = Locale(identifier: "zh_CN")
        format.timeZone = TimeZone(identifier: report?.timeZoneID ?? model.profile.timeZoneID) ?? .current
        return now.formatted(format)
    }
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
                        metricLink(.energy, "身体电量", "battery.75percent", report?.energy.estimate ?? MetricEstimate(), .cyan)
                        metricLink(.stress, "生理压力", "waveform.path.ecg", report?.stress ?? MetricEstimate(), .orange)
                    }
                    if let report { dayRhythm(report); sleepCard(report); weeklyChart(report); activityCard(report) }
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
                    Text(dateLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.busy { ProgressView() }
                else { Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(wristMint) }
            }
        }
    }
    private var readiness: some View {
        let metric = report?.readiness ?? MetricEstimate(reasons: ["noReadableSamples"])
        return NavigationLink { MetricDetailView(kind: .readiness, title: "训练准备度", metric: metric, report: report, now: now) } label: {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("训练准备度", systemImage: "leaf.fill").font(.subheadline).foregroundStyle(wristMint)
                    Text(MetricTier.label(for: .readiness, value: MetricExplanation(metric, at: now).displayValue).map { "准备度\($0)" } ?? "从了解自己开始")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(metricStatus(metric, at: now)).font(.caption).foregroundStyle(.secondary)
                    Text("查看依据  ↗").font(.caption2).foregroundStyle(wristMint).padding(.top, 4)
                }
                Spacer(minLength: 0)
                ScoreRing(value: MetricExplanation(metric, at: now).displayValue)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.18), wristCard], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(.plain)
    }
    private func metricLink(_ kind: ComplicationMetric, _ title: String, _ symbol: String, _ metric: MetricEstimate, _ color: Color) -> some View {
        NavigationLink { MetricDetailView(kind: kind, title: title, metric: metric, report: report, now: now) } label: {
            SmallMetricCard(kind: kind, title: title, symbol: symbol, metric: metric, color: color, now: now)
        }.buttonStyle(.plain)
    }
    private func dayRhythm(_ report: HealthReport) -> some View {
        let timeline = DayTimeline(report: report, at: now)
        let ticks = stride(from: 0.0, through: timeline.day.duration, by: 3 * 3600).map { timeline.day.start.addingTimeInterval($0) }
        let asOf = report.asOf.formatted(reportStyle(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits), report.timeZoneID))
        let isolatedEnergy = Set(Dictionary(grouping: timeline.energy, by: \.segment).filter { $0.value.count == 1 }.keys)
        let isolatedStress = Set(Dictionary(grouping: timeline.stress, by: \.segment).filter { $0.value.count == 1 }.keys)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("一天的节奏").font(.headline)
                Spacer()
                if timeline.isPastDay {
                    Text("\(timeline.day.start.formatted(reportStyle(.dateTime.month().day(), report.timeZoneID))) · 非今天").font(.caption).foregroundStyle(.orange)
                }
            }
            HStack { Text("身体电量").font(.caption).foregroundStyle(.cyan); Spacer() }
            if timeline.energy.isEmpty {
                Text(MetricExplanation(report.energy.estimate, at: now).detail).font(.caption).foregroundStyle(.secondary).frame(minHeight: 60)
            } else {
                Chart {
                    ForEach(Array(timeline.spans.enumerated()), id: \.offset) { _, span in
                        RectangleMark(xStart: .value("开始", span.interval.start), xEnd: .value("结束", span.interval.end), yStart: .value("下", 0), yEnd: .value("上", 100))
                            .foregroundStyle(span.kind == .asleep ? Color.indigo.opacity(0.28) : Color.yellow.opacity(0.22))
                    }
                    ForEach(Array(timeline.energy.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("时间", point.at), y: .value("电量", point.value), series: .value("连续段", "e\(point.segment)"))
                            .foregroundStyle(.cyan).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.linear)
                        if isolatedEnergy.contains(point.segment) {
                            PointMark(x: .value("时间", point.at), y: .value("电量", point.value)).symbolSize(12).foregroundStyle(.cyan)
                        }
                    }
                }
                .chartXScale(domain: timeline.day.start ... timeline.day.end).chartYScale(domain: 0...100).chartLegend(.hidden)
                .chartXAxis { hourAxis(ticks, report.timeZoneID) }
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { _ in AxisValueLabel(); AxisGridLine().foregroundStyle(.white.opacity(0.04)) } }
                .frame(height: 100)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("身体电量曲线，截至\(asOf)，最近\(Int(timeline.energy.last!.value.rounded()))，睡眠\(timeline.spans.filter { $0.kind == .asleep }.count)段，运动\(timeline.spans.filter { $0.kind == .workout }.count)段")
            }
            HStack { Text("生理压力").font(.caption).foregroundStyle(.orange); Spacer() }
            if timeline.stress.isEmpty {
                Text(MetricExplanation(report.stress, at: now).detail).font(.caption).foregroundStyle(.secondary).frame(minHeight: 40)
            } else {
                Chart(Array(timeline.stress.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("时间", point.at), y: .value("压力", point.value), series: .value("连续段", "s\(point.segment)"))
                        .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 1.8)).interpolationMethod(.linear)
                    if point.activity || isolatedStress.contains(point.segment) {
                        PointMark(x: .value("时间", point.at), y: .value("压力", point.value))
                            .symbol(point.activity ? .square : .circle).symbolSize(point.activity ? 18 : 10).foregroundStyle(point.activity ? Color.yellow : Color.orange)
                    }
                }
                .chartXScale(domain: timeline.day.start ... timeline.day.end).chartYScale(domain: 0...100).chartLegend(.hidden)
                .chartXAxis { hourAxis(ticks, report.timeZoneID) }
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { _ in AxisValueLabel(); AxisGridLine().foregroundStyle(.white.opacity(0.04)) } }
                .frame(height: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("生理压力曲线，截至\(asOf)，\(Set(timeline.stress.map(\.segment)).count)段已观测，最近\(Int(timeline.stress.last!.value))")
            }
            if !timeline.energy.isEmpty || !timeline.stress.isEmpty {
                HStack(spacing: 12) {
                    if !timeline.energy.isEmpty {
                        legend(Color.indigo.opacity(0.6), "睡眠")
                        legend(Color.yellow.opacity(0.6), "运动")
                    }
                    if timeline.stress.contains(where: \.activity) { Label("运动中压力", systemImage: "square.fill").foregroundStyle(.yellow) }
                }.font(.caption2).foregroundStyle(.secondary)
                Text("曲线只连接已观测时段，空白处没有记录，不代表休息或数值为0。").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func hourAxis(_ ticks: [Date], _ timeZoneID: String) -> some AxisContent {
        AxisMarks(values: ticks) { value in
            AxisValueLabel { if let date = value.as(Date.self) { Text(hourLabel(date, timeZoneID)) } }
            AxisGridLine().foregroundStyle(.white.opacity(0.04))
        }
    }
    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 8); Text(title) }
    }
    private func sleepCard(_ report: HealthReport) -> some View {
        NavigationLink { SleepDetailView(report: report) } label: { sleepSummary(report) }.buttonStyle(.plain)
    }
    private func sleepSummary(_ report: HealthReport) -> some View {
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
                                    .accessibilityLabel("\(SleepLane(phase)?.title ?? "") \(Int(duration)) 分钟")
                            }
                        }
                    }
                }.frame(height: 8)
            }
            HStack { Text("7 日睡眠债"); Spacer(); Text(report.sleepDebtMinutes.map { "\(Int($0)) 分钟" } ?? "记录不足") }.font(.caption).foregroundStyle(.secondary)
            HStack { Text("入睡时间偏差"); Spacer(); Text(report.regularityMinutes.map { "\(Int($0)) 分钟" } ?? "记录不足") }.font(.caption).foregroundStyle(.secondary)
            Text("查看阶段与小睡  ↗").font(.caption2).foregroundStyle(.purple)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func weeklyChart(_ report: HealthReport) -> some View {
        let series = TrendSeries(history: report.history, metric: trend, endingAt: report.day, timeZoneID: report.timeZoneID)
        let unit = ["readiness": "分", "sleep": "小时", "load": ""][trend.rawValue] ?? ""
        let format: (Double) -> String = { trend == .sleep ? $0.formatted(.number.precision(.fractionLength(1))) : "\(Int($0.rounded()))" }
        // Categories avoid Charts binning days in the device time zone instead of the analysis time zone.
        let labels = series.days.map { $0.day.formatted(reportStyle(.dateTime.weekday(.abbreviated), report.timeZoneID)) }
        let dates = series.days.map { $0.day.formatted(reportStyle(.dateTime.month().day(), report.timeZoneID)) }
        // Observed load includes unfinished and partly observed days, which are lower bounds, so no mean.
        let footer = trend == .load ? "已观测负荷，含未完成日" : series.mean.map { "均值 \(format($0))\(unit)" }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近 7 天").font(.headline)
                Spacer()
                Picker("指标", selection: $trend) { ForEach(TrendMetric.allCases, id: \.self) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented).frame(maxWidth: 200)
            }
            Chart(Array(series.days.enumerated()), id: \.offset) { index, day in
                if let value = day.value {
                    BarMark(x: .value("日期", labels[index]), y: .value(trend.title, value)).foregroundStyle(wristMint.gradient).cornerRadius(4)
                }
            }
            .chartXScale(domain: labels)
            .chartYScale(domain: trend == .readiness ? 0...100 : 0...max(1, (series.days.compactMap(\.value).max() ?? 1) * 1.15))
            .frame(height: 110)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("最近7天\(trend == .load ? "已观测负荷" : trend.title)，" + series.days.indices.map { index in
                "\(dates[index])\(series.days[index].value.map { format($0) + unit } ?? "无记录")"
            }.joined(separator: "，"))
            Text((["有效 \(series.validDays)/7 天"] + [footer].compactMap { $0 } + ["缺失日保留空白"]).joined(separator: " · "))
                .font(.caption2).foregroundStyle(.secondary)
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
    let kind: ComplicationMetric
    let title: String
    let metric: MetricEstimate
    let report: HealthReport?
    let now: Date
    var body: some View {
        List {
            Section {
                HStack { Spacer(); ScoreRing(value: MetricExplanation(metric, at: now).displayValue); Spacer() }.padding()
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
                    ForEach(rows, id: \.input) { ContributionRowView(row: $0) }
                } header: { Text("与个人基线比较") } footer: { Text("按模型内标准化后的偏离判断，接近基线表示偏离很小；只描述对该估算的作用，不是医疗或训练建议。") }
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

/// Dates shown in the report's fixed analysis time zone, which may differ from the device time zone.
func reportStyle(_ style: Date.FormatStyle, _ timeZoneID: String) -> Date.FormatStyle {
    var style = style
    style.timeZone = TimeZone(identifier: timeZoneID) ?? .current
    style.locale = Locale(identifier: "zh_CN")
    return style
}
/// Two-digit hour in the analysis time zone, without the locale's hour suffix.
func hourLabel(_ date: Date, _ timeZoneID: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
    return String(format: "%02d", calendar.component(.hour, from: date))
}
