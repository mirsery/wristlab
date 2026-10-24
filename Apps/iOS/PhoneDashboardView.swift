import SwiftUI
import Charts
import WristlabCore

private enum PhoneTab: String, CaseIterable, Identifiable {
    case today, sleep, activity, trends, account
    var id: String { rawValue }
    var title: String {
        switch self { case .today: "今天"; case .sleep: "睡眠"; case .activity: "活动"; case .trends: "趋势"; case .account: "我的" }
    }
    var symbol: String {
        switch self { case .today: "sun.max"; case .sleep: "moon.stars"; case .activity: "figure.run"; case .trends: "chart.xyaxis.line"; case .account: "person.crop.circle" }
    }
}

struct PhoneDashboardView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject private var cloud = AppServices.cloudPreferences
    @State private var settings = false
    @State private var planningSheet: PlanningSheet?
    @State private var trendsNavigation = TrendsNavigationState()
    @State private var showingRhythm = false
    @State private var selectedTab: PhoneTab = .today
    @State private var managingPlan = false
    @State private var todayPath: [ComplicationMetric] = []
    @State private var scrollPositions: [PhoneTab: String] = [:]
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
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                page(.today) { todayContent }
                    .navigationDestination(for: ComplicationMetric.self) { kind in
                        PhoneCareClock(demoDate: model.demoEnabled ? (report?.asOf ?? DemoData.previewDate) : nil) { time in
                            MetricDetailView(kind: kind, title: kind.title, metric: estimate(kind), report: report, now: time)
                        }
                    }
            }
            .tabItem { Label(PhoneTab.today.title, systemImage: PhoneTab.today.symbol) }.tag(PhoneTab.today)
            NavigationStack {
                if let report {
                    SleepDetailView(report: report) { pageStatus }
                        .refreshable { await model.refresh() }
                } else { page(.sleep) { missingTopic(.sleep) } }
            }
            .id("sleep-\(dataIdentity)")
            .tabItem { Label(PhoneTab.sleep.title, systemImage: PhoneTab.sleep.symbol) }.tag(PhoneTab.sleep)
            NavigationStack {
                page(.activity) { activityContent }
                    .navigationDestination(isPresented: $managingPlan) { ActivityPlanManagementView(model: model) }
            }
                .id("activity-\(dataIdentity)")
                .tabItem { Label(PhoneTab.activity.title, systemImage: PhoneTab.activity.symbol) }.tag(PhoneTab.activity)
            NavigationStack {
                trendsPage
                    .navigationDestination(isPresented: $showingRhythm) { rhythmDetails }
            }
                .id("trends-\(dataIdentity)")
                .tabItem { Label(PhoneTab.trends.title, systemImage: PhoneTab.trends.symbol) }.tag(PhoneTab.trends)
            NavigationStack { page(.account) { accountContent } }
                .tabItem { Label(PhoneTab.account.title, systemImage: PhoneTab.account.symbol) }.tag(PhoneTab.account)
        }
        .tint(wristMint)
        .environment(\.timeZone, TimeZone(identifier: report?.timeZoneID ?? model.profile.timeZoneID) ?? .current)
        .sheet(isPresented: $settings) { SettingsView(model: model) }
        .sheet(item: $planningSheet) { sheet in
            switch sheet {
            case .movement: MovementPlanForm(model: model)
            case .goal: WeightGoalForm(model: model)
            case .weight: WeightEntryForm(model: model)
            case .automatic: AutomaticPlanForm(model: model)
            }
        }
        .onChange(of: dataIdentity) { _, _ in
            todayPath = []
            scrollPositions = [:]
            planningSheet = nil
            managingPlan = false
            showingRhythm = false
            trendsNavigation.resetContentPositions()
        }
        .onChange(of: trendsNavigation.interfacePreferences) { _, value in
            guard !model.demoEnabled, value != cloud.preferences else { return }
            let context = cloud.contextID
            Task { await cloud.edit(value, context: context) }
        }
        .onChange(of: cloud.preferenceRevision) { _, _ in
            if !model.demoEnabled { trendsNavigation.apply(cloud.preferences) }
        }
        .onChange(of: model.demoEnabled) { _, enabled in
            if !enabled { trendsNavigation.apply(cloud.preferences) }
        }
    }
    private var dataIdentity: String { "\(model.demoEnabled)-\(report != nil)-\(model.contentResetID)" }
    private func estimate(_ kind: ComplicationMetric) -> MetricEstimate {
        switch kind {
        case .readiness: report?.readiness ?? MetricEstimate(reasons: ["noReadableSamples"])
        case .energy: report?.energy.estimate ?? MetricEstimate(reasons: ["noReadableSamples"])
        case .stress: report?.stress ?? MetricEstimate(reasons: ["noReadableSamples"])
        }
    }
    private func page<Content: View>(_ tab: PhoneTab, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if tab == .today { header.id("header") }
                pageStatus.id("status")
                content()
            }
            .scrollTargetLayout()
            .padding(.horizontal, 22).padding(.vertical, 12)
        }
        .scrollPosition(id: Binding(get: { scrollPositions[tab] }, set: { scrollPositions[tab] = $0 }), anchor: .top)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Today hides its navigation bar; without a backdrop scrolled text shows behind the clock.
            if tab == .today {
                Color.clear.frame(height: 0)
                    .background(wristBackground, ignoresSafeAreaEdges: .top)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("today.statusBarBackdrop")
                    .accessibilityHidden(true)
            }
        }
        .background(wristBackground)
        .navigationTitle(tab.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(tab == .today ? .hidden : .visible, for: .navigationBar)
        .refreshable { await model.refresh() }
    }
    private var pageStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.demoEnabled {
                HStack {
                    Label("合成演示 · 非健康评估", systemImage: "sparkles")
                    Spacer()
                    Button("退出") { model.demoEnabled = false }
                }.foregroundStyle(wristMint)
            }
            if let report {
                Text("报告 \(report.day.formatted(reportStyle(.dateTime.year().month().day(), report.timeZoneID))) · \(report.source == .demo ? "合成记录" : "Apple 健康")")
                Text("生成于 \(report.asOf.formatted(reportStyle(.dateTime.month().day().hour().minute(), report.timeZoneID))) · \(report.timeZoneID)")
            }
            if !model.demoEnabled {
                HStack(alignment: .top, spacing: 8) {
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status)
                }
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(wristCard, in: RoundedRectangle(cornerRadius: 14))
    }
    private var todayContent: some View {
        Group {
            Button { selectedTab = .activity } label: {
                MovementPlanCard(model: model, configure: { planningSheet = .movement }, compact: true)
            }.buttonStyle(.plain).id("daily-plan")
            PhoneCareSection(report: report, demo: model.demoEnabled)
            if let report {
                Button { selectedTab = .sleep } label: { sleepSummary(report) }.buttonStyle(.plain).id("sleep")
                Button { selectedTab = .activity } label: { activityCard(report) }.buttonStyle(.plain).id("activity")
            } else { emptyState.id("empty") }
        }
    }
    @ViewBuilder private var activityContent: some View {
        MovementPlanCard(model: model, configure: { managingPlan = true }).id("movement-plan")
        ActivityWeekSummary(model: model).id("week-summary")
        if let report {
            activityCard(report).id("overview")
            NavigationLink { activityDetails } label: {
                Label("查看负荷与运动详情", systemImage: "chart.bar.doc.horizontal")
            }.buttonStyle(.bordered).id("activity-details")
        } else { missingTopic(.activity) }
    }
    private var activityDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageStatus
                if let report {
                    let breakdown = ActivityBreakdown(report.activity)
                    loadDetail(breakdown.day, title: "全天已观测心率区间").id("zones")
                    if breakdown.workouts.isEmpty {
                        topicNote("暂无运动记录", "没有记录不等于休息日，也不能据此计算零负荷。").id("workouts")
                    } else {
                        Text("各次运动").font(.headline).id("workouts")
                        Text("编号仅用于区分记录，不代表发生顺序；当前报告未提供运动类型和起止时间。").font(.caption).foregroundStyle(.secondary)
                        ForEach(breakdown.workouts) { workout in
                            loadDetail(workout.detail, title: "运动记录 \(workout.number)").id("workout-\(workout.id)")
                        }
                    }
                } else { missingTopic(.activity) }
            }.padding(22)
        }
        .background(wristBackground).navigationTitle("负荷与运动详情").navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
    }
    private var trendsPage: some View {
        ZStack {
            ForEach(TrendsSection.allCases, id: \.self) { section in
                trendsSectionPage(section)
                    .opacity(trendsNavigation.selected == section ? 1 : 0)
                    .allowsHitTesting(trendsNavigation.selected == section)
                    .accessibilityHidden(trendsNavigation.selected != section)
            }
        }
        .navigationTitle("趋势").navigationBarTitleDisplayMode(.inline)
    }
    private func trendsSectionPage(_ section: TrendsSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageStatus.id("status")
                trendsSectionPicker.id("section-picker")
                Text(section.periodExplanation).font(.caption).foregroundStyle(.secondary).id("period")
                trendsContent(section)
            }
            .scrollTargetLayout().padding(.horizontal, 22).padding(.vertical, 12)
        }
        .scrollPosition(id: Binding(get: { trendsNavigation.position(for: section) }, set: { trendsNavigation.rememberPosition($0, for: section) }), anchor: .top)
        .background(wristBackground)
        .refreshable { await model.refresh() }
    }
    @ViewBuilder private var trendsSectionPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("趋势主题", selection: $trendsNavigation.selected) {
                ForEach(TrendsSection.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.menu)
        } else {
            Picker("趋势主题", selection: $trendsNavigation.selected) {
                ForEach(TrendsSection.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
        }
    }
    @ViewBuilder private func trendsContent(_ section: TrendsSection) -> some View {
        switch section {
        case .health:
            if let report {
                weeklyChart(report, section: .health).id("history")
                weeklyReview(report).id("review")
                Button { showingRhythm = true } label: { Label("查看报告日的一天节奏", systemImage: "waveform.path.ecg") }
                    .buttonStyle(.bordered).id("rhythm-link")
                if model.moodSupported { moodCard(report).id("mood") }
            } else { missingTopic(.trends) }
        case .movement:
            MovementWeekReview(model: model).id("movement-review")
            if let report { weeklyChart(report, section: .movement).id("load-history") }
            else { topicNote("暂无健康负荷历史", "本地计划仍可回顾；缺少健康观测不能作为零负荷。").id("load-empty") }
            Button("前往活动，查看今日安排") { selectedTab = .activity }.buttonStyle(.bordered).id("activity-link")
        case .weight:
            WeightProgressCard(model: model, record: { planningSheet = .weight }, editGoal: { planningSheet = .goal }).id("weight-progress")
        }
    }
    private var rhythmDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageStatus
                if let report { dayRhythm(report) }
                else { missingTopic(.trends) }
            }.padding(22)
        }
        .background(wristBackground).navigationTitle("报告日节奏").navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
    }
    @ViewBuilder private var accountContent: some View {
        NavigationLink {
            CloudDataCenterView(cloud: cloud, model: model)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label("iCloud与数据中心", systemImage: "icloud").font(.headline)
                Text(cloud.state?.account.title ?? "检查当前iCloud账户").font(.subheadline)
                Text(model.demoEnabled ? "合成演示 · 云同步暂停" : cloud.state?.phase.title ?? "默认不上传数据").font(.caption)
                Text("首版仅界面偏好，不含健康、体重、目标与计划。").font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain).id("cloud-center")
        VStack(alignment: .leading, spacing: 18) {
            Label("数据留在设备上", systemImage: "lock.shield").font(.headline)
            Button("建立或调整运动计划") { planningSheet = .movement }
            Button("自动生成运动周计划") { planningSheet = .automatic }
            Button("设置或暂停减重目标") { planningSheet = .goal }
            Button("记录体重（仅本机）") { planningSheet = .weight }
            Button("连接 / 检查 Apple 健康") { Task { await model.connect() } }.disabled(model.busy || model.demoEnabled)
            Button("刷新数据") { Task { await model.refresh() } }.disabled(model.busy || model.demoEnabled)
            if let report {
                ForEach(ComplicationMetric.allCases) { kind in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title).font(.subheadline)
                        Text(metricStatus(estimate(kind), at: now)).font(.caption).foregroundStyle(.secondary)
                        Text("有效基线 \(estimate(kind).baselineDays) 天").font(.caption)
                    }.accessibilityElement(children: .combine)
                }
                Text("模型 \(report.modelVersion)").font(.caption).foregroundStyle(.secondary)
            }
            Button { settings = true } label: { Label("偏好、来源与全部设置", systemImage: "slider.horizontal.3") }
                .buttonStyle(.bordered)
            if !model.demoEnabled {
                Button("看看合成演示") { Task { await model.enableDemo() } }
            }
            Text("各类来源优先级、晨报通知、睡眠目标和本地清除均在设置中。健康授权完成不代表一定有可读取记录。").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(wristCard, in: RoundedRectangle(cornerRadius: 24)).id("account")
    }
    private func missingTopic(_ tab: PhoneTab) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topicNote("暂无\(tab.title)数据", "连接健康后显示已有记录；缺少输入或历史不足时会解释原因。空读取不能确定是否拒绝授权。")
            Button("前往我的，连接健康或查看演示") { selectedTab = .account }
        }.id("empty")
    }
    private func topicNote(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func loadDetail(_ detail: ActivityLoadDetail, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LabeledContent("已观测负荷", value: detail.load.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "暂无数据")
            LabeledContent("观测覆盖", value: "\(Int((detail.coverage * 100).rounded()))%")
            if let zones = detail.zoneMinutes {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, minutes in
                    LabeledContent(zoneTitle(index), value: "\(minutes.formatted(.number.precision(.fractionLength(1)))) 分钟")
                }
            } else { Text("暂无可展示的心率区间观测；未记录时段不会算作低强度。").font(.caption).foregroundStyle(.secondary) }
            if detail.isLowerBound { Text("尚未结算或覆盖不足：负荷只表示已观测下界。").font(.caption).foregroundStyle(.orange) }
            Text("区间分钟仅统计已观测心率，不等于总运动时长；分区按个人心率储备比例。").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func zoneTitle(_ index: Int) -> String {
        let titles = ["区间0 · 低于50%", "区间1 · 50–60%", "区间2 · 60–70%", "区间3 · 70–80%", "区间4 · 80–90%", "区间5 · 至少90%"]
        return titles.indices.contains(index) ? titles[index] : "心率区间"
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
    private func dayRhythm(_ report: HealthReport) -> some View {
        let timeline = DayTimeline(report: report, at: now)
        let ticks = stride(from: 0.0, through: timeline.day.duration, by: 3 * 3600).map { timeline.day.start.addingTimeInterval($0) }
        let asOf = report.asOf.formatted(reportStyle(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits), report.timeZoneID))
        let isolatedEnergy = Set(Dictionary(grouping: timeline.energy, by: \.segment).filter { $0.value.count == 1 }.keys)
        let isolatedStress = Set(Dictionary(grouping: timeline.stress, by: \.segment).filter { $0.value.count == 1 }.keys)
        let moodMarks = model.moodSupported ? MoodOverview(entries: model.displayedMoods, stressTimeline: report.stressTimeline,
                                                           timeZoneID: report.timeZoneID, now: now).todayMarkers.filter { $0 >= timeline.day.start && $0 < timeline.day.end } : []
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
                Chart {
                    ForEach(Array(timeline.stress.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("时间", point.at), y: .value("压力", point.value), series: .value("连续段", "s\(point.segment)"))
                            .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 1.8)).interpolationMethod(.linear)
                        if point.activity || isolatedStress.contains(point.segment) {
                            PointMark(x: .value("时间", point.at), y: .value("压力", point.value))
                                .symbol(point.activity ? .square : .circle).symbolSize(point.activity ? 18 : 10).foregroundStyle(point.activity ? Color.yellow : Color.orange)
                        }
                    }
                    ForEach(Array(moodMarks.enumerated()), id: \.offset) { _, mark in
                        RuleMark(x: .value("心情记录", mark)).foregroundStyle(.purple.opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXScale(domain: timeline.day.start ... timeline.day.end).chartYScale(domain: 0...100).chartLegend(.hidden)
                .chartXAxis { hourAxis(ticks, report.timeZoneID) }
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { _ in AxisValueLabel(); AxisGridLine().foregroundStyle(.white.opacity(0.04)) } }
                .frame(height: 70)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("生理压力曲线，截至\(asOf)，\(Set(timeline.stress.map(\.segment)).count)段已观测，最近\(Int(timeline.stress.last!.value))" + (moodMarks.isEmpty ? "" : "，今天有\(moodMarks.count)条心情记录"))
            }
            if !timeline.energy.isEmpty || !timeline.stress.isEmpty {
                HStack(spacing: 12) {
                    if !timeline.energy.isEmpty {
                        legend(Color.indigo.opacity(0.6), "睡眠")
                        legend(Color.yellow.opacity(0.6), "运动")
                    }
                    if timeline.stress.contains(where: \.activity) { Label("运动中压力", systemImage: "square.fill").foregroundStyle(.yellow) }
                    if !moodMarks.isEmpty { Label("心情记录", systemImage: "line.diagonal").foregroundStyle(.purple) }
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
    private func sleepSummary(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("主睡眠", systemImage: "moon.stars.fill").foregroundStyle(.purple); Spacer(); Text(report.sleep.settled ? "已汇总" : "暂定").foregroundStyle(.secondary) }.font(.subheadline)
            Text(report.sleep.totalMinutes.map { "\(Int($0) / 60) 小时 \(Int($0) % 60) 分钟" } ?? "暂无睡眠记录").font(.system(.title2, design: .rounded, weight: .semibold))
            Text("查看阶段与小睡  ↗").font(.caption2).foregroundStyle(.purple)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func trendUnit(_ metric: TrendMetric) -> String {
        switch metric { case .readiness: "分"; case .sleep: "小时"; case .load: ""; case .nightHRV: " ms"; case .restingHeartRate: " bpm" }
    }
    private func trendValue(_ metric: TrendMetric, _ value: Double) -> String {
        metric == .sleep ? value.formatted(.number.precision(.fractionLength(1))) : "\(Int(value.rounded()))"
    }
    private func weeklyChart(_ report: HealthReport, section: TrendsSection) -> some View {
        let trend = trendsNavigation.metric(for: section) ?? .readiness
        let trendLength = trendsNavigation.length(for: section) ?? 7
        let series = TrendSeries(history: report.history, metric: trend, endingAt: report.day, timeZoneID: report.timeZoneID, length: trendLength)
        let unit = trendUnit(trend)
        let isLine = trend == .nightHRV || trend == .restingHeartRate
        let band: (low: Double, high: Double)? = report.personalRanges.flatMap { ranges in
            trend == .nightHRV ? (ranges.hrvLow, ranges.hrvHigh) : trend == .restingHeartRate ? (ranges.restingLow, ranges.restingHigh) : nil
        }
        // Categories avoid Charts binning days in the device time zone instead of the analysis time zone.
        let labels = series.days.map { $0.day.formatted(reportStyle(trendLength == 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.defaultDigits).day(), report.timeZoneID)) }
        let shownLabels = trendLength == 7 ? labels : labels.enumerated().filter { ($0.offset - labels.count + 1) % 5 == 0 }.map(\.element)
        let dates = series.days.map { $0.day.formatted(reportStyle(.dateTime.month().day(), report.timeZoneID)) }
        let values = series.days.compactMap(\.value) + (band.map { [$0.low, $0.high] } ?? [])
        let domain: ClosedRange<Double> = trend == .readiness ? 0...100
            : isLine ? max(0, (values.min() ?? 0) * 0.9)...max(1, (values.max() ?? 1) * 1.1) : 0...max(1, (values.max() ?? 1) * 1.15)
        // Observed load includes unfinished and partly observed days, which are lower bounds, so no mean.
        let footer = trend == .load ? "已观测负荷，含未完成日" : series.mean.map { "均值 \(trendValue(trend, $0))\(unit)" }
        return VStack(alignment: .leading, spacing: 12) {
            Text(section == .movement ? "已观测负荷趋势" : "健康指标趋势").font(.headline)
            if section == .health {
                Picker("指标", selection: Binding(get: { trend }, set: { trendsNavigation.selectHealthMetric($0) })) {
                    ForEach(TrendsSection.health.metrics, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.menu)
            }
            Picker("图表天数", selection: Binding(get: { trendLength }, set: { trendsNavigation.setLength($0, for: section) })) { Text("7天").tag(7); Text("30天").tag(30) }.pickerStyle(.segmented)
            Text("仅控制此图表的最近\(trendLength)日，不改变周回顾周期。").font(.caption2).foregroundStyle(.secondary)
            Chart {
                if let band {
                    RectangleMark(yStart: .value("下限", band.low), yEnd: .value("上限", band.high)).foregroundStyle(wristMint.opacity(0.12))
                }
                ForEach(Array(series.days.enumerated()), id: \.offset) { index, day in
                    if let value = day.value {
                        if isLine {
                            let segment: String = "s\(series.days[..<index].filter { $0.value == nil }.count)"
                            LineMark(x: .value("日期", labels[index]), y: .value(trend.title, value), series: .value("连续段", segment))
                                .foregroundStyle(wristMint)
                            PointMark(x: .value("日期", labels[index]), y: .value(trend.title, value)).symbolSize(trendLength == 7 ? 30 : 12).foregroundStyle(wristMint)
                        } else {
                            BarMark(x: .value("日期", labels[index]), y: .value(trend.title, value)).foregroundStyle(wristMint.gradient).cornerRadius(trendLength == 7 ? 4 : 1)
                        }
                    }
                }
            }
            .chartXScale(domain: labels)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.04))
                    // Thin the 30-day labels while keeping every category on the scale.
                    if let label = value.as(String.self), shownLabels.contains(label) { AxisValueLabel() }
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("最近\(trendLength)天\(trend == .load ? "已观测负荷" : trend.title)，" + series.days.indices.map { index in
                "\(dates[index])\(series.days[index].value.map { trendValue(trend, $0) + unit } ?? "无记录")"
            }.joined(separator: "，") + (band.map { "，个人基线区间\(trendValue(trend, $0.low))到\(trendValue(trend, $0.high))\(unit)" } ?? ""))
            Text((["有效 \(series.validDays)/\(trendLength) 天"] + [footer].compactMap { $0 } + ["缺失日保留空白"]).joined(separator: " · "))
                .font(.caption2).foregroundStyle(.secondary)
            if isLine {
                Text(report.personalRanges.map { "浅色带为个人基线区间：今天准备度所用的夜间基线（\($0.days)个有效夜晚），偏离不到0.5个尺度即“接近个人基线”。按今天的基线画出，不是人群或医学正常值。" }
                     ?? "暂无个人基线区间：需要今天的准备度使用夜间数据，且同一睡眠来源至少14个有效夜晚；较早的缓存在刷新后生成。")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if trend == .readiness && trendLength == 30 {
                Text("各日准备度按当前读取到的数据重算；较早日期可用的基线较短，可能仍在校准而留空。").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func weeklyReview(_ report: HealthReport) -> some View {
        let review = WeeklyReview(history: report.history, endingAt: report.day, timeZoneID: report.timeZoneID)
        return VStack(alignment: .leading, spacing: 10) {
            Text("近7日回顾").font(.headline)
            ForEach(review.rows, id: \.metric) { row in
                let unit = trendUnit(row.metric)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(row.metric.title).font(.subheadline)
                        Spacer()
                        Text(row.differenceText.map { $0 + unit } ?? "记录不足")
                            .font(.subheadline).monospacedDigit().foregroundStyle(row.differenceText == nil ? .secondary : .primary)
                    }
                    Text("近7日 \(row.thisWeekMean.map { trendValue(row.metric, $0) + unit } ?? "—")（\(row.thisWeekDays)/7天） · 此前28日 \(row.previousMean.map { trendValue(row.metric, $0) + unit } ?? "—")（\(row.previousDays)/28天）")
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            Text("近7日截至报告日\(report.day.formatted(reportStyle(.dateTime.year().month().day(), report.timeZoneID)))。近7日至少3天、此前28日至少10天有效记录才计算均值；差值按显示的均值相减，只陈述差别，不说明原因。").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func moodCard(_ report: HealthReport) -> some View {
        let overview = MoodOverview(entries: model.displayedMoods, stressTimeline: report.stressTimeline, timeZoneID: report.timeZoneID, now: now, reportAsOf: report.asOf)
        let time = reportStyle(.dateTime.month(.defaultDigits).day().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits), report.timeZoneID)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("心情记录", systemImage: "face.smiling").font(.headline).foregroundStyle(.purple)
                Spacer()
                if model.demoEnabled { Text("合成演示").font(.caption2).foregroundStyle(wristMint) }
            }
            if !model.demoEnabled && !model.moodConnected {
                Text("读取你在健康或正念App里记录的心情，与同时段压力并列显示。只读，只在本机使用。").font(.caption).foregroundStyle(.secondary)
                Button { Task { await model.connectMoods() } } label: { Text("连接心情记录").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.bordered)
            } else if overview.rows.isEmpty {
                Text("最近7天没有心情记录。可以在健康App或Apple Watch的正念App记录；没有记录不代表读取被拒绝。").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(overview.rows.prefix(8), id: \.entry.id) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.classificationText).font(.subheadline)
                            Spacer()
                            Text("\(row.entry.at.formatted(time)) · \(row.entry.kind.title)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                        }
                        if let detail = moodDetail(row) { Text(detail).font(.caption).foregroundStyle(.secondary) }
                        Text(moodStress(row)).font(.caption).foregroundStyle(row.stress == nil ? Color.secondary : Color.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if let message = model.moodStatus { Text(message).font(.caption2).foregroundStyle(.orange) }
            Text("心情来自你的自报，Wristlab不从心率或压力推算心情；并列显示不表示两者有因果关系。").font(.caption2).foregroundStyle(.secondary)
        }.padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
    private func moodDetail(_ row: MoodRow) -> String? {
        let associations = row.associationsText.map { "关于" + $0 }
        let parts = [row.labelsText, associations].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    private func moodStress(_ row: MoodRow) -> String {
        if row.afterReport { return "晚于本次报告，刷新后配对" }
        guard let stress = row.stress else { return "同时段无生理压力估算" }
        let prefix = row.entry.kind == .dailyMood ? (row.dayInProgress ? "当天截至目前的生理压力中位数" : "当天生理压力中位数") : "同时段生理压力"
        return "\(prefix) \(stress) · \(row.stressTier ?? "")" + (row.duringActivity ? "（运动中）" : "")
    }
    private func activityCard(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("报告日活动", systemImage: "figure.run").font(.headline).foregroundStyle(.orange)
            HStack { Text("体能输出"); Spacer(); Text(report.activity.exertion.value.map { "\($0) / 100" } ?? "暂无数据").monospacedDigit() }
            HStack { Text("已观测负荷"); Spacer(); Text(report.activity.day.load.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") }.font(.subheadline)
            Text(report.activity.reasons.first.map(reasonText) ?? "当日数值为已观测估算，未记录时段不会当成零负荷。").font(.caption).foregroundStyle(.secondary)
            if let target = report.activity.target { Text("历史参考区间 \(Int(target.lower))–\(Int(target.upper))").font(.caption).foregroundStyle(wristMint) }
            else { Text("有效历史或当前准备度不足，暂无法生成参考区间。").font(.caption).foregroundStyle(.secondary) }
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
