import SwiftUI
import Charts
import WristlabCore

enum PlanningSheet: String, Identifiable {
    case movement, goal, weight, automatic
    var id: String { rawValue }
}

struct MovementPlanCard: View {
    @ObservedObject var model: DashboardModel
    var configure: () -> Void
    var compact = false
    @State private var replacing = false
    @State private var replacementActivity = ""
    @State private var replacementMinutes = 30
    private var clock: AnalysisClock? { try? AnalysisClock(timeZoneID: model.planningTimeZone) }
    var body: some View {
        let selectedDate = model.planningNow
        let sourceIsDemo = model.demoEnabled
        let suggestion = try? PlanSuggestion(state: model.displayedPlanning, report: model.displayed, now: selectedDate, timeZoneID: model.planningTimeZone)
        let todayEntry = model.displayedPlanning.entries.first { $0.day == clock?.label(selectedDate) }
        let active = (try? model.displayedPlanning.usesAutomatic(at: selectedDate, timeZoneID: model.planningTimeZone)) == true || model.displayedPlanning.plan?.status == .active
        VStack(alignment: .leading, spacing: 12) {
            Label("今天的安排", systemImage: "calendar").font(.headline)
            Text(selectedDate.formatted(reportStyle(.dateTime.month().day(), model.planningTimeZone))).font(.caption).foregroundStyle(.secondary)
            if let summary = try? ActivityPlanPresentation(state: model.displayedPlanning, now: selectedDate, timeZoneID: model.planningTimeZone) {
                Text(summary.mode.title).font(.caption).foregroundStyle(wristMint)
                if let start = summary.pendingAutomaticStart {
                    Text("已采纳的自动计划将于\(start.formatted(reportStyle(.dateTime.month().day(), model.planningTimeZone)))生效。").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let suggestion {
                if let activity = suggestion.activity, let minutes = suggestion.minutes {
                    Text("\(activity) · \(minutes) 分钟").font(.title3)
                    Text("时长由你设定，不由状态分数换算。").font(.caption).foregroundStyle(.secondary)
                }
                Text(suggestion.message).font(.subheadline)
                if let entry = try? model.displayedPlanning.scheduledEntry(at: selectedDate, timeZoneID: model.planningTimeZone) {
                    WorkoutProgressView(model: model, entry: entry, day: selectedDate)
                }
                if !compact, active, suggestion.activity != nil {
                    if todayEntry?.status == nil || todayEntry?.status == .planned {
                        ViewThatFits {
                            HStack { actions(suggestion, at: selectedDate, sourceIsDemo: sourceIsDemo) }
                            VStack(alignment: .leading, spacing: 12) { actions(suggestion, at: selectedDate, sourceIsDemo: sourceIsDemo) }
                        }
                        Button("换一个活动（自行选择）") { replacing.toggle() }
                        if replacing {
                            TextField("替换活动", text: $replacementActivity)
                            Stepper("\(replacementMinutes) 分钟", value: $replacementMinutes, in: 1...1440)
                            Button("保存当天替换，不标记完成") {
                                let now = selectedDate, zone = model.planningTimeZone
                                Task {
                                    if await model.updatePlanning(expectedDemo: sourceIsDemo, { try $0.replaceToday(activity: replacementActivity, minutes: replacementMinutes, at: now, timeZoneID: zone) }) { replacing = false }
                                }
                            }
                        }
                    } else {
                        Button("撤销手动标记") { Task { await model.markMovement(.planned, at: selectedDate, expectedDemo: sourceIsDemo) } }
                    }
                }
            }
            if !compact {
                let hasPlan = (try? ActivityPlanPresentation(state: model.displayedPlanning, now: selectedDate, timeZoneID: model.planningTimeZone).hasPlan) ?? false
                Button(hasPlan ? "管理计划" : "建立计划", action: configure)
                if let estimate = model.displayed?.readiness {
                    Text("依据：\(metricStatus(estimate, at: model.planningNow))").font(.caption).foregroundStyle(.secondary)
                    Text("数据时间：\(estimate.effectiveAt?.formatted(reportStyle(.dateTime.month().day().hour().minute(), model.planningTimeZone)) ?? "无当前采样")").font(.caption2)
                }
                Text("\(PlanSuggestion.version) · 仅用于安排参考，不是运动处方或安全额度。").font(.caption2).foregroundStyle(.secondary)
                if let notice = model.planningNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        .disabled(model.planningBusy || model.busy)
        .onChange(of: model.demoEnabled) { _, _ in resetReplacement() }
        .onChange(of: model.displayed != nil) { _, _ in resetReplacement() }
        .onChange(of: model.planningTimeZone) { _, _ in resetReplacement() }
        .onChange(of: clock?.label(model.planningNow)) { _, _ in resetReplacement() }
    }
    private func resetReplacement() {
        replacing = false
        replacementActivity = ""
        replacementMinutes = 30
    }
    @ViewBuilder private func actions(_ suggestion: PlanSuggestion, at selectedDate: Date, sourceIsDemo: Bool) -> some View {
        Button("手动完成") { Task { await model.markMovement(.completed, at: selectedDate, expectedDemo: sourceIsDemo) } }.buttonStyle(.borderedProminent)
        Button("今天休息") { Task { await model.markMovement(.rested, at: selectedDate, expectedDemo: sourceIsDemo) } }.buttonStyle(.bordered)
        if suggestion.canChooseLight {
            Button("换为预设轻量活动") { Task { await model.markMovement(.planned, at: selectedDate, expectedDemo: sourceIsDemo, light: true) } }
        }
    }
}

struct MovementPlanForm: View {
    @ObservedObject var model: DashboardModel
    private let sourceIsDemo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var plan: MovementPlan
    private var validationMessage: String? {
        if plan.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写常做的活动。" }
        if plan.activity.count > 100 || plan.lightActivity.count > 100 { return "活动名称请保持在100个字以内。" }
        if plan.weekdays.isEmpty { return "请至少选择一个运动日。" }
        if !plan.lightActivity.isEmpty && plan.lightMinutes > plan.minutes { return "轻量安排的时长不能超过常规安排。" }
        return nil
    }
    init(model: DashboardModel) {
        self.model = model
        sourceIsDemo = model.demoEnabled
        _plan = State(initialValue: model.displayedPlanning.plan ?? MovementPlan(goal: .active, weekdays: [], activity: "", minutes: 30))
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.demoEnabled { Text("仅编辑合成演示，不写入真实数据").foregroundStyle(wristMint) }
                Section("目标与活动") {
                    Picker("目标", selection: $plan.goal) { ForEach(MovementGoal.allCases, id: \.self) { Text($0.title).tag($0) } }
                    TextField("常做活动，例如步行", text: $plan.activity)
                    Stepper("每次 \(plan.minutes) 分钟", value: $plan.minutes, in: 1...1440, step: 1)
                }
                Section("每周日期") {
                    ForEach(Array(zip([2, 3, 4, 5, 6, 7, 1], ["周一", "周二", "周三", "周四", "周五", "周六", "周日"])), id: \.0) { value, title in
                        Toggle(title, isOn: Binding(get: { plan.weekdays.contains(value) }, set: {
                            if $0 { plan.weekdays.insert(value) } else { plan.weekdays.remove(value) }
                        }))
                    }
                }
                Section("可选轻量安排") {
                    TextField("轻量活动（可留空）", text: $plan.lightActivity)
                    Stepper("\(plan.lightMinutes) 分钟", value: $plan.lightMinutes, in: 1...1440)
                    Text("轻量时长须不超过常规时长；数值由你选择，不是医学建议。").font(.caption)
                }
                Section {
                    Toggle("暂停计划", isOn: Binding(get: { plan.status != .active }, set: { plan.status = $0 ? .paused : .active }))
                    Text("修改仅影响今天尚未处理的安排和未来日期，已完成或休息的记录保留；各版本按分析日期保存。").font(.caption)
                    Text("保存此模板会切回手动安排；取消不会改变当前模式。").font(.caption).foregroundStyle(.secondary)
                    if let notice = model.planningNotice { Text(notice).foregroundStyle(.secondary) }
                    if let validationMessage { Text(validationMessage).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("运动计划")
            .scrollDismissesKeyboard(.interactively)
            .onAppear { model.planningNotice = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.planningBusy ? "保存中…" : "保存") {
                        let now = model.planningNow, zone = model.planningTimeZone
                        Task { if await model.updatePlanning(expectedDemo: sourceIsDemo, { try $0.configurePlan(plan, at: now, timeZoneID: zone) }) { dismiss() } }
                    }.disabled(model.busy || model.planningBusy || validationMessage != nil)
                }
            }
        }
    }
}

struct WeightProgressCard: View {
    @ObservedObject var model: DashboardModel
    var record: () -> Void
    var editGoal: () -> Void
    private let unit = WeightUnit.kilograms
    @State private var editing: WeightEntry?
    @State private var deleting: WeightEntry?
    @State private var visibleRecords = 10
    private var goalHasEnded: Bool {
        guard let goal = model.displayedPlanning.goal, goal.status == .active,
              let clock = try? AnalysisClock(timeZoneID: model.planningTimeZone) else { return false }
        return model.planningNow >= clock.day(containing: goal.deadline).end
    }
    private var progress: WeightProgress? {
        try? WeightProgress(records: model.displayedPlanning.weights, now: model.planningNow, timeZoneID: model.planningTimeZone)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("体重与目标", systemImage: "scalemass").font(.headline)
            if let goal = model.displayedPlanning.goal {
                Text("设定目标 \(formatted(goal.targetKilograms)) \(unit.title) · \(goalHasEnded ? "已到期，待回顾" : goal.status == .active ? "进行中" : "已暂停")")
                if goalHasEnded { Text("期望日期已结束，可回顾进展或重新设定日期；不会追加未完成运动量。").font(.caption).foregroundStyle(.secondary) }
                Text("期望日期 \(goal.deadline.formatted(reportStyle(.dateTime.year().month().day(), model.planningTimeZone))) · 仅为意向，不预测达标时间").font(.caption).foregroundStyle(.secondary)
                if let latest = progress?.days.last {
                    let remaining = latest.kilograms - goal.targetKilograms
                    Text("最近记录日 \(latest.day.formatted(reportStyle(.dateTime.year().month().day(), model.planningTimeZone))) · \(formatted(latest.kilograms)) \(unit.title)").font(.caption)
                    Text(remaining <= 0 ? "已达到设定目标" : "距设定目标 \(formatted(remaining)) \(unit.title)")
                } else { Text("尚无体重记录，不计算进度").font(.caption) }
            } else { Text("未设置减重目标，也可以只记录体重。").font(.subheadline) }
            if let progress, !progress.days.isEmpty {
                Chart(progress.days) { day in
                    LineMark(x: .value("日期", day.day), y: .value("体重", unit.display(day.kilograms)), series: .value("连续记录", day.segment))
                    PointMark(x: .value("日期", day.day), y: .value("体重", unit.display(day.kilograms)))
                }.chartYScale(domain: .automatic(includesZero: false)).chartLegend(.hidden).frame(height: 150)
                    .accessibilityLabel("体重趋势；\(progress.days.count)个有效记录日，缺失日期不连接。单位\(unit.title)")
                Text("本周进行中 · 有记录 \(progress.currentWeekDays)/7 天").font(.caption)
                Text("本周日值均重：\(progress.currentWeekMean.map(formatted) ?? "至少3个不同日才计算")\(progress.currentWeekMean == nil ? "" : " " + unit.title)")
                    .font(.subheadline)
                if let difference = progress.difference {
                    Text("较上周 \(unit.display(difference).formatted(.number.sign(strategy: .always()).precision(.fractionLength(2)))) \(unit.title)").font(.caption)
                }
            } else { Text("暂无体重数据，缺失不会填零。").font(.caption).foregroundStyle(.secondary) }
            Text("同日最后一次采样参与周均，每日等权；单次变化不代表脂肪变化。首版不计算饮食或热量预算。").font(.caption2).foregroundStyle(.secondary)
            HStack { Button("记录体重", action: record); Spacer(); Button(goalHasEnded ? "回顾或续期目标" : "设置或调整目标", action: editGoal) }
            DisclosureGroup("手动记录明细（\(model.displayedPlanning.weights.count)条）") {
                ForEach(model.displayedPlanning.weights.sorted {
                    if $0.at != $1.at { return $0.at > $1.at }
                    if $0.recordedAt != $1.recordedAt { return $0.recordedAt > $1.recordedAt }
                    return $0.id > $1.id
                }.prefix(visibleRecords)) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(entry.at.formatted(reportStyle(.dateTime.year().month().day().hour().minute(), model.planningTimeZone))) · \(formatted(entry.kilograms)) \(unit.title)")
                        HStack {
                            Text("手动记录").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("编辑") { editing = entry }.disabled(model.planningBusy || model.busy)
                            Button("删除", role: .destructive) { deleting = entry }.disabled(model.planningBusy || model.busy)
                        }
                    }.padding(.vertical, 5)
                }
                if model.displayedPlanning.weights.count > visibleRecords {
                    Button("再显示10条（还有\(model.displayedPlanning.weights.count - visibleRecords)条）") { visibleRecords += 10 }
                }
            }
            if let notice = model.planningNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(18).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        .sheet(item: $editing) { WeightEntryForm(model: model, entry: $0) }
        .onChange(of: model.demoEnabled) { _, _ in editing = nil; deleting = nil; visibleRecords = 10 }
        .alert("删除这条手动体重记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                if let identifier = deleting?.id {
                    let sourceIsDemo = model.demoEnabled
                    Task { _ = await model.updatePlanning(expectedDemo: sourceIsDemo) { $0.weights.removeAll { $0.id == identifier } } }
                }
                deleting = nil
            }
        } message: { Text("删除后重新计算趋势，不修改Apple健康数据。") }
    }
    private func formatted(_ kilograms: Double) -> String { unit.display(kilograms).formatted(.number.precision(.fractionLength(2))) }
}

struct WeightEntryForm: View {
    @ObservedObject var model: DashboardModel
    private let sourceIsDemo: Bool
    var entry: WeightEntry?
    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    @State private var at: Date
    @FocusState private var editingInput: Bool
    private let unit = WeightUnit.kilograms
    private var kilograms: Double? { Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var validationMessage: String? {
        guard let kilograms, kilograms.isFinite, kilograms > 0 else { return "请输入大于0的体重，单位为公斤。" }
        if at > model.planningNow { return "测量时间不能晚于现在。" }
        return nil
    }
    init(model: DashboardModel, entry: WeightEntry? = nil) {
        self.model = model; self.entry = entry
        sourceIsDemo = model.demoEnabled
        _value = State(initialValue: entry.map { String($0.kilograms) } ?? "")
        _at = State(initialValue: entry?.at ?? model.planningNow)
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.demoEnabled { Text("合成演示记录").foregroundStyle(wristMint) }
                TextField("体重 kg", text: $value).keyboardType(.decimalPad).focused($editingInput)
                Text("单位：公斤（kg）").font(.caption).foregroundStyle(.secondary)
                DatePicker("测量时间", selection: $at, in: ...model.planningNow)
                Text("仅保存在本机，不写入Apple健康。填写实际测量时间，不能填写未来记录。").font(.caption)
                if let notice = model.planningNotice { Text(notice).font(.caption) }
                if let validationMessage { Text(validationMessage).font(.caption).foregroundStyle(.orange) }
            }
            .navigationTitle(entry == nil ? "记录体重" : "编辑体重")
            .scrollDismissesKeyboard(.interactively)
            .onAppear { model.planningNotice = nil }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { editingInput = false }
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.planningBusy ? "保存中…" : "保存") {
                        let entryKilograms = unit.kilograms(kilograms ?? .nan)
                        let updated = WeightEntry(id: entry?.id ?? UUID().uuidString, kilograms: entryKilograms, at: at, recordedAt: model.planningNow)
                        Task {
                            if await model.updatePlanning(expectedDemo: sourceIsDemo, { state in
                                state.weights.removeAll { $0.id == updated.id }; state.weights.append(updated)
                            }) { dismiss() }
                        }
                    }.disabled(model.busy || model.planningBusy || validationMessage != nil)
                }
            }
        }
    }
}

struct WeightGoalForm: View {
    @ObservedObject var model: DashboardModel
    private let sourceIsDemo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var startValue: String
    @State private var target: String
    @State private var start: Date
    @State private var deadline: Date
    @State private var paused: Bool
    @FocusState private var editingInput: Bool
    private let unit = WeightUnit.kilograms
    private var startKilograms: Double? { Double(startValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var targetKilograms: Double? { Double(target.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var validationMessage: String? {
        guard let startKilograms, startKilograms.isFinite, startKilograms > 0,
              let targetKilograms, targetKilograms.isFinite, targetKilograms > 0 else { return "请填写大于0的起始和目标体重，单位为公斤。" }
        if targetKilograms >= startKilograms { return "减重目标必须低于起始体重。" }
        if start > model.planningNow { return "起始日期不能晚于现在。" }
        if deadline <= start { return "期望截止日期必须晚于起始日期。" }
        return nil
    }
    init(model: DashboardModel) {
        self.model = model
        sourceIsDemo = model.demoEnabled
        let goal = model.displayedPlanning.goal
        _startValue = State(initialValue: goal.map { String($0.startKilograms) } ?? "")
        _target = State(initialValue: goal.map { String($0.targetKilograms) } ?? "")
        _start = State(initialValue: goal?.start ?? model.planningNow)
        _deadline = State(initialValue: goal?.deadline ?? Calendar.current.date(byAdding: .day, value: 90, to: model.planningNow) ?? model.planningNow)
        _paused = State(initialValue: goal?.status == .paused)
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.demoEnabled { Text("仅修改合成演示目标").foregroundStyle(wristMint) }
                Section("用户设定目标") {
                    Text("单位：公斤（kg）").font(.caption).foregroundStyle(.secondary)
                    TextField("起始体重 \(unit.title)", text: $startValue).keyboardType(.decimalPad).focused($editingInput)
                    TextField("目标体重 \(unit.title)", text: $target).keyboardType(.decimalPad).focused($editingInput)
                    DatePicker("起始日期", selection: $start, in: ...model.planningNow, displayedComponents: .date)
                    DatePicker("期望截止日期", selection: $deadline, displayedComponents: .date)
                    Toggle("暂停目标", isOn: $paused)
                }
                Section {
                    Text("目标与期限由你设定，不判断健康适宜性、不预测达标日，也不生成饮食或热量处方。儿童、孕哺及临床管理场景不提供个性化减重建议。")
                    Text("调整后保留旧目标快照；暂停期间仍可记录体重。")
                    if let notice = model.planningNotice { Text(notice).foregroundStyle(.secondary) }
                    if let validationMessage { Text(validationMessage).foregroundStyle(.orange) }
                }.font(.caption)
            }
            .navigationTitle("减重目标")
            .scrollDismissesKeyboard(.interactively)
            .onAppear { model.planningNotice = nil }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { editingInput = false }
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.planningBusy ? "保存中…" : "保存") {
                        let goal = WeightGoal(startKilograms: unit.kilograms(startKilograms ?? .nan), targetKilograms: unit.kilograms(targetKilograms ?? .nan),
                                              start: start, deadline: deadline, status: paused ? .paused : .active)
                        Task { if await model.updatePlanning(expectedDemo: sourceIsDemo, { $0.weightGoals.append(goal) }) { dismiss() } }
                    }.disabled(model.busy || model.planningBusy || validationMessage != nil)
                }
            }
        }
    }
}

struct MovementWeekReview: View {
    @ObservedObject var model: DashboardModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本周计划回顾", systemImage: "checklist").font(.headline)
            if let clock = try? AnalysisClock(timeZoneID: model.planningTimeZone) {
                let weekday = clock.calendar.component(.weekday, from: model.planningNow)
                let start = clock.shiftedDay(model.planningNow, by: -((weekday + 5) % 7))
                let entries = (0..<7).compactMap { try? model.displayedPlanning.scheduledEntry(at: clock.shiftedDay(start, by: $0), timeZoneID: model.planningTimeZone) }
                Text("安排 \(entries.count) 次 · 手动完成 \(entries.filter { $0.status == .completed }.count) · 休息 \(entries.filter { $0.status == .rested }.count)")
                Text("本周进行中；休息单独统计，未完成的安排不自动补课。完成标记由你确认，不代表自动识别运动。").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
    }
}
