import SwiftUI
import Charts
import WristlabCore

typealias WatchCareTab = WatchCarePage

struct WatchCareDashboard: View {
    @ObservedObject var model: WatchReportModel
    @ObservedObject var care: WatchCareModel
    @ObservedObject var bridge: WatchBridge
    let demoReport: HealthReport?
    let demoEnabled: Bool
    let now: Date
    @Binding var tab: WatchCareTab
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var moodSheet = false
    @State private var demoMood: CareMood?
    @State private var messageHidden = false
    private var snapshot: DisplaySnapshot? {
        demoEnabled ? demoReport.map { DisplaySnapshot(report: $0, producerID: "synthetic", epoch: 0, sequence: 0) } : model.snapshot
    }
    private var pressure: CareMetricPresentation { CareMetricPresentation(snapshot: snapshot, metric: .stress, at: now, demo: demoEnabled) }
    private var daily: DailyActivityReport? { demoEnabled ? previewActivity : model.envelope?.careProjection?.daily }
    private var systemZone: String { demoEnabled ? (demoReport?.timeZoneID ?? "UTC") : TimeZone.current.identifier }
    private var mood: CareMood? { demoEnabled ? demoMood : care.mood?.mood }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack { Picker("页面", selection: $tab) { ForEach(WatchCareTab.allCases) { Text($0.title).tag($0) } }; page(tab) }
            } else {
                TabView(selection: $tab) { ForEach(WatchCareTab.allCases) { page($0).tag($0) } }.tabViewStyle(.page)
            }
        }
        .background(wristBackground.ignoresSafeArea())
        .sheet(isPresented: $moodSheet) { CareMoodForm(care: care, demo: demoEnabled, demoMood: $demoMood) }
        .onChange(of: demoEnabled) { _, _ in moodSheet = false; demoMood = nil; messageHidden = false }
        .onChange(of: care.generation) { _, _ in moodSheet = false }
        .onChange(of: model.envelope?.generation) { _, _ in
            if model.envelope?.cleanupPending == true { moodSheet = false }
        }
    }
    private func page(_ page: WatchCareTab) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if demoEnabled { Label("合成演示 · 非健康判断", systemImage: "sparkles").font(.caption2).foregroundStyle(wristMint) }
                switch page {
                case .care: home
                case .activity: activity
                case .state: state
                }
            }.padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var home: some View {
        Group {
            if !messageHidden {
                VStack(alignment: .leading, spacing: 8) {
                    Text("给自己一点轻松").font(.headline).foregroundStyle(wristMint)
                    Text(CareMessage.text(pressure: pressure, mood: mood,
                        achieved: daily?.currentRings(at: now, timeZoneID: systemZone)?.hasAchievement == true)).font(.body)
                    Button("收起关怀") { messageHidden = true }.font(.caption2).buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            NavigationLink(value: WatchPage.metric(.stress)) { CareStatusCard(metric: .stress, display: pressure) }.buttonStyle(.plain)
            Button { tab = .activity } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label(stepText, systemImage: "figure.walk").font(.headline)
                    Text(exerciseText).font(.caption)
                    Text("手表活动 · 系统今天").font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(wristCard, in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain)
            Button { moodSheet = true } label: { Label(mood.map { "自报心情 · \($0.title)" } ?? "现在心情怎么样？", systemImage: mood?.symbol ?? "questionmark.circle") }
                .disabled(!demoEnabled && !care.canUse())
            Text("可以记录，也可以跳过；心情由你表达。").font(.caption2).foregroundStyle(.secondary)
            dataStatus
        }
    }
    private var activity: some View {
        Group {
            Text("手表可读健康汇总 · 系统今天\n\(systemZone)").font(.caption2).foregroundStyle(.secondary)
            Label(stepText, systemImage: "figure.walk").font(.title3)
            if let rings = daily?.currentRings(at: now, timeZoneID: systemZone) {
                ActivityRingsView(rings: rings)
                if rings.paused == true { Text("活动目标已暂停，今天按自己的节奏来。").font(.caption) }
                Text("目标来自系统，没闭环也不用补课。锻炼分钟不是全部运动时长。").font(.caption2).foregroundStyle(.secondary)
            } else { Text("暂无当前圆环记录；可能无数据、未允许读取或尚未同步。").font(.caption) }
            if let daily {
                if daily.stepsFailed || daily.ringsFailed { Text("部分读取未完成，保留对应上次记录及时间。").font(.caption2).foregroundStyle(.orange) }
                if let date = daily.stepsReadAt { Text("步数读取：\(date.formatted(.dateTime.month().day().hour().minute()))").font(.caption2) }
                if let date = daily.ringsReadAt { Text("圆环读取：\(date.formatted(.dateTime.month().day().hour().minute()))").font(.caption2) }
                Text("最近7个系统日 · 缺口未补零").font(.caption)
                Chart(daily.steps) { entry in
                    if let count = entry.count { BarMark(x: .value("日期", entry.day, unit: .day), y: .value("步数", count)).foregroundStyle(wristMint) }
                }.chartXScale(domain: stepDomain(daily))
                    .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { AxisValueLabel(format: .dateTime.day()) } }
                    .frame(height: 100).environment(\.timeZone, TimeZone(identifier: daily.timeZoneID) ?? .current)
                    .accessibilityLabel("最近7个系统日步数，缺少记录的日期不画柱，今天进行中。")
                if daily.steps.allSatisfy({ $0.count == nil }) { Text("这7天暂无可读步数，空白不是零步。").font(.caption2) }
            }
            if !demoEnabled {
                Button(care.activityEnabled ? "刷新日常活动" : "连接日常活动") { Task { if care.activityEnabled { await care.refresh() } else { await care.connect() } } }
                    .disabled(care.busy || !care.canUse())
                if care.busy { ProgressView() }
                Text(care.notice ?? care.status).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private var state: some View {
        Group {
            CareStatusCard(metric: .stress, display: pressure)
            Text(pressure.detail).font(.caption)
            if let context = reportContext {
                Text("日内生理压力 · \(context.timeZoneID)").font(.caption)
                CarePressureChart(points: context.points).environment(\.timeZone, TimeZone(identifier: context.timeZoneID) ?? .current)
                if let notice = context.graphNotice { Text(notice).font(.caption2) }
                Text("缺口不连接；运动单列，浅色段为部分估算。").font(.caption2).foregroundStyle(.secondary)
                if let heart = context.heartRate, let baseline = context.baselineHeartRate {
                    Text("当前桶心率 \(heart.formatted(.number.precision(.fractionLength(0)))) bpm\n个人基线 \(baseline.formatted(.number.precision(.fractionLength(0)))) bpm").font(.caption)
                }
                Text("这是读取时的桶内心率，不是实时测量；仅说明HRV是否参与，不反推未保存数值。").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(model.envelope?.mode == .phone && !demoEnabled ? "手机快照暂不包含趋势和输入详情，可打开手机查看。" : "暂无可绘制的本地报告，请主动连接手表健康。")
                    .font(.caption)
            }
            ForEach([ComplicationMetric.readiness, .energy]) { metric in
                NavigationLink(value: WatchPage.metric(metric)) {
                    CareStatusCard(metric: metric, display: CareMetricPresentation(snapshot: snapshot, metric: metric, at: now, demo: demoEnabled))
                }.buttonStyle(.plain)
            }
            dataStatus
        }
    }
    private var stepText: String { daily?.currentSteps(at: now, timeZoneID: systemZone).map { $0.formatted(.number.precision(.fractionLength(0))) + " 步" } ?? "步数待记录" }
    private func stepDomain(_ daily: DailyActivityReport) -> ClosedRange<Date> {
        guard let clock = try? AnalysisClock(timeZoneID: daily.timeZoneID) else { return daily.day...daily.day.addingTimeInterval(1) }
        return clock.shiftedDay(daily.day, by: -6)...clock.shiftedDay(daily.day, by: 1)
    }
    private var exerciseText: String { daily?.currentRings(at: now, timeZoneID: systemZone)?.exercise.value.map { "锻炼 " + $0.formatted(.number.precision(.fractionLength(0))) + " 分钟" } ?? "活动分钟暂无记录" }
    private var reportContext: CareReportContext? {
        if demoEnabled, let demoReport, let snapshot { return CareReportContext(report: demoReport, snapshot: snapshot) }
        guard model.envelope?.mode == .local, let context = model.envelope?.careProjection?.context, context.matches(snapshot) else { return nil }
        return context
    }
    private var dataStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(demoEnabled ? "合成示意" : model.envelope?.originTitle ?? "来源不可用")
            if let snapshot { Text("报告读取：\(snapshot.asOf.formatted(.dateTime.month().day().hour().minute())) · \(snapshot.timeZoneID)") }
            if !demoEnabled {
                Text(model.envelope?.mode == .phone ? bridge.status : model.status)
                if let notice = model.notice { Text(notice).foregroundStyle(.orange) }
                if let notice = care.notice { Text(notice).foregroundStyle(.orange) }
                if model.envelope?.mode == nil {
                    NavigationLink("连接手表健康", value: WatchPage.settings)
                    Button("使用手机同步") { Task { await model.select(.phone); bridge.requestRefresh() } }
                }
            }
        }.font(.caption2).foregroundStyle(.secondary)
    }
    private var previewActivity: DailyActivityReport? {
        guard let clock = try? AnalysisClock(timeZoneID: systemZone) else { return nil }
        let today = clock.day(containing: now).start
        let steps = (0..<7).map { offset in DaySteps(day: clock.shiftedDay(today, by: -offset), count: offset == 3 ? nil : Double(6320 - offset * 400)) }
        return DailyActivityReport(timeZoneID: systemZone, day: today, steps: steps, stepsReadAt: now,
            rings: ActivityRings(move: ActivityRing(value: 320, goal: 400, unit: "kcal"), exercise: ActivityRing(value: 23, goal: 30, unit: "min"), stand: ActivityRing(value: 8, goal: 12, unit: "h"), paused: false), ringsReadAt: now)
    }
}

struct CareStatusCard: View {
    let metric: ComplicationMetric
    let display: CareMetricPresentation
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: display.symbol).font(.title2).foregroundStyle(wristMint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title).font(.caption).foregroundStyle(.secondary)
                Text(display.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                if let note = display.inputNote { Text(note).font(.caption2).foregroundStyle(.secondary) }
                if let fraction = display.energyFraction {
                    Gauge(value: fraction) { Text("身体电量估算") }.gaugeStyle(.linearCapacity).labelsHidden().tint(wristMint).accessibilityHidden(true)
                }
            }
            Spacer(minLength: 0)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(wristCard, in: RoundedRectangle(cornerRadius: 18)).accessibilityElement(children: .combine)
    }
}

struct CarePressureChart: View {
    let points: [CareStressPoint]
    var body: some View {
        Chart(points) { point in
            if let level = point.level {
                RuleMark(xStart: .value("开始", point.start), xEnd: .value("结束", point.end), y: .value("等级", level))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: point.partial ? [3, 3] : []))
                    .foregroundStyle(point.partial ? Color.secondary : wristMint)
                    .accessibilityLabel("\(["较低", "常态", "偏高", "较高"][level])，\(point.partial ? "部分估算，可能仅心率" : "可用输入估算")")
                    .accessibilityValue("\(point.start.formatted(.dateTime.hour().minute())) 至 \(point.end.formatted(.dateTime.hour().minute()))")
            } else if point.activity {
                PointMark(x: .value("时间", point.start), y: .value("情境", 4)).symbol(.diamond).foregroundStyle(.secondary)
                    .accessibilityLabel("运动情境，不判断心理紧张")
            }
        }
        .chartYScale(domain: -0.5...4.5)
        .chartYAxis { AxisMarks(values: [0, 1, 2, 3, 4]) { axis in AxisValueLabel { if let level = axis.as(Int.self) { Text(["较低", "常态", "偏高", "较高", "运动"][level]) } } } }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisValueLabel(format: .dateTime.hour()) } }
        .frame(height: 135).accessibilityLabel("日内生理压力等级趋势，空白为缺失，运动以菱形标记。")
    }
}

struct ActivityRingsView: View {
    let rings: ActivityRings
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ring("活动", rings.move, .pink)
            ring("锻炼", rings.exercise, .green)
            ring("站立", rings.stand, .cyan)
        }
    }
    private func ring(_ title: String, _ ring: ActivityRing, _ color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 5)
                if rings.paused != true, let fraction = ring.fraction { Circle().trim(from: 0, to: fraction).stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                Image(systemName: rings.paused == true ? "pause" : ring.goal == nil ? "questionmark" : "figure.walk").font(.caption)
            }.frame(width: 36, height: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption)
                Text((ring.value.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—") + " / " +
                    (ring.goal.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "目标未知") + " " + ring.unit).font(.caption).monospacedDigit()
            }
        }.accessibilityElement(children: .combine)
    }
}

struct CareMoodForm: View {
    @ObservedObject var care: WatchCareModel
    let demo: Bool
    @Binding var demoMood: CareMood?
    @State private var selection: CareMood?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @State private var capturedAt = Date()
    @State private var capturedZone = TimeZone.current.identifier
    @State private var capturedGeneration: UUID?
    var body: some View {
        NavigationStack {
            List {
                Text(demo ? "合成演示：不保存真实心情" : "只保存在本机今天，不用于评分。")
                ForEach(CareMood.allCases) { mood in
                    Button { selection = mood } label: {
                        HStack { Label(mood.title, systemImage: mood.symbol); Spacer(); if selection == mood { Image(systemName: "checkmark") } }
                    }
                }
                if let error { Text(error).foregroundStyle(.orange) }
                Button("确认记录") { save(selection) }.disabled(selection == nil)
                if demo ? demoMood != nil : care.mood != nil { Button("删除今天记录", role: .destructive) { save(nil) } }
                Button("跳过") { dismiss() }
            }.navigationTitle("此刻心情")
        }.onAppear { capturedGeneration = care.generation; selection = demo ? demoMood : care.mood?.mood }
    }
    private func save(_ mood: CareMood?) {
        if demo { demoMood = mood; dismiss(); return }
        do {
            guard let capturedGeneration else { return }
            try care.saveMood(mood, capturedAt: capturedAt, capturedZone: capturedZone, expectedGeneration: capturedGeneration)
            dismiss()
        } catch { self.error = "日期、来源或保存状态有变化，请关闭后重新选择。" }
    }
}

struct WatchCareMetricDetail: View {
    @ObservedObject var model: WatchReportModel
    let demo: HealthReport?
    let metric: ComplicationMetric
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tick in
            let snapshot = demo.map { DisplaySnapshot(report: $0, producerID: "synthetic", epoch: 0, sequence: 0) } ?? model.snapshot
            let display = CareMetricPresentation(snapshot: snapshot, metric: metric, at: demo?.asOf ?? tick.date, demo: demo != nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if demo != nil { Text("合成演示 · 非健康判断").font(.caption) }
                    CareStatusCard(metric: metric, display: display)
                    Text(display.detail).font(.body)
                    Text(model.envelope?.originTitle ?? "来源不可用").font(.caption2)
                    if let snapshot { Text(snapshot.asOf, style: .time).font(.caption2) }
                    if demo == nil, model.envelope?.mode == .local { Button("刷新手表本地报告") { Task { await model.refreshLocal() } }.disabled(model.busy) }
                    Text(model.notice ?? model.status).font(.caption2)
                }.padding(12)
            }.background(wristBackground)
        }.navigationTitle(metric.shortTitle)
    }
}
