import SwiftUI
import WristlabCore

struct WorkoutProgressView: View {
    @ObservedObject var model: DashboardModel
    let entry: MovementEntry
    let day: Date
    @State private var previousSeconds: Double?
    @State private var revisionMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let progress = model.completion(for: entry, at: day) {
                if let seconds = progress.observedSeconds {
                    Text("已记录 \(Int(seconds / 60)) / 目标 \(entry.minutes) 分钟")
                    ProgressView(value: progress.fraction ?? 0)
                    Text(progress.completed ? "健康运动记录已达到计划时长" : "已记录时长尚不足目标，不代表你没有做其它运动")
                        .font(.caption).foregroundStyle(progress.completed ? wristMint : .secondary)
                    Text("按未取整秒数统计：\(seconds.formatted(.number.precision(.fractionLength(1))))秒").font(.caption2)
                } else { Text("尚无可匹配记录，完成度待确认").font(.caption).foregroundStyle(.secondary) }
                if progress.excludedRecords > 0 { Text("\(progress.excludedRecords)条匹配记录缺少可靠活跃时段，未自动计入。").font(.caption2).foregroundStyle(.orange) }
                if progress.otherRecords > 0 { Text("另有\(progress.otherRecords)条其它类型运动，未计入此项目标。").font(.caption2).foregroundStyle(.secondary) }
                if !progress.sources.isEmpty { Text("来源：" + progress.sources.joined(separator: "、")).font(.caption2).foregroundStyle(.secondary) }
                if !progress.notes.isEmpty {
                    DisclosureGroup("未自动计入的记录") {
                        ForEach(progress.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(note.activity) · \(note.reason)")
                                Text("\(note.start.formatted(reportStyle(.dateTime.month().day().hour().minute(), model.planningTimeZone)))–\(note.end.formatted(reportStyle(.dateTime.month().day().hour().minute(), model.planningTimeZone)))")
                                Text("整条记录时长：\(note.durationSeconds.map { ($0 / 60).formatted(.number.precision(.fractionLength(1))) + "分钟" } ?? "旧记录未保存时长") · 来源：\(note.source)")
                            }.font(.caption2).padding(.vertical, 4)
                        }
                    }
                }
            } else { Text("此活动暂不支持自动匹配，可手动确认。").font(.caption).foregroundStyle(.secondary) }
            if entry.status != .planned { Text(entry.status == .completed ? "手动确认完成（不额外累加分钟）" : "已选择休息；健康记录仍独立展示").font(.caption) }
            if let clock = try? AnalysisClock(timeZoneID: model.planningTimeZone),
               let original = model.displayedPlanning.automatic?.weeks.reversed().compactMap({ week in week.sessions.first { clock.label($0.day) == entry.day } }).first,
               original.minutes != entry.minutes || original.activity.title != entry.activity {
                Text("采用手动调整目标；原计划为\(original.activity.title)\(original.minutes)分钟。").font(.caption2).foregroundStyle(.secondary)
            }
            Text("记录读取于：\(model.displayed?.asOf.formatted(reportStyle(.dateTime.month().day().hour().minute(), model.planningTimeZone)) ?? "暂无读取记录")").font(.caption2).foregroundStyle(.secondary)
            Text("这是运动计划完成度，不是每日减脂结果。").font(.caption2).foregroundStyle(.secondary)
            Text("完成度按当前读取记录重算；删除、修订或更换来源可能令已达标回退，手动确认仍独立保留。").font(.caption2).foregroundStyle(.secondary)
            if let revisionMessage { Text(revisionMessage).font(.caption2).foregroundStyle(.orange) }
        }
        .onAppear { previousSeconds = model.completion(for: entry, at: day)?.observedSeconds }
        .onChange(of: model.displayed?.inputRevision) { _, _ in
            let current = model.completion(for: entry, at: day)?.observedSeconds
            if let previousSeconds, (current ?? 0) < previousSeconds {
                revisionMessage = "本次读取的匹配时段减少，已重新计算完成度；记录修订、删除或来源变化都可能导致回退。"
            } else { revisionMessage = nil }
            previousSeconds = current
        }
    }
}

struct AutomaticWeekCard: View {
    @ObservedObject var model: DashboardModel
    var configure: () -> Void
    @State private var feedback: WeekFeedback = .none
    @State private var draft: GeneratedWeek?
    @State private var notice: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("自动周计划", systemImage: "calendar.badge.clock").font(.headline)
            Button("按偏好生成并预览", action: configure).buttonStyle(.borderedProminent)
            if let automatic = model.displayedPlanning.automatic, let week = automatic.weeks.last {
                Text(automatic.enabled ? "已采纳，按开始日期生效" : "当前使用手动安排").font(.subheadline)
                Text("最近采纳周：\(week.weekStart.formatted(reportStyle(.dateTime.month().day(), week.timeZoneID))) · \(week.totalMinutes)分钟").font(.caption)
                Text("\(week.ruleVersion) · 每次采纳保留版本").font(.caption2).foregroundStyle(.secondary)
                ForEach(week.sessions) { session in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(session.day.formatted(reportStyle(.dateTime.month().day().weekday(), week.timeZoneID))) · \(session.activity.title) · \(session.minutes)分钟")
                            .font(.subheadline)
                        if week.timeZoneID == model.planningTimeZone, session.day <= model.planningNow,
                           let entry = try? model.displayedPlanning.scheduledEntry(at: session.day, timeZoneID: model.planningTimeZone) {
                            WorkoutProgressView(model: model, entry: entry, day: session.day)
                        }
                    }
                }
                Picker("这一周的感受", selection: $feedback) { ForEach(WeekFeedback.allCases, id: \.self) { Text($0.title).tag($0) } }
                if week.timeZoneID != model.planningTimeZone {
                    Text("分析时区已改变；旧周保留原时区，请重新生成当前时区的安排。").font(.caption).foregroundStyle(.orange)
                }
                Button("生成下一周调整草案") { generateNext(week) }
                    .disabled(week.timeZoneID != model.planningTimeZone)
                if automatic.enabled {
                    Button("切回手动安排") {
                        let sourceIsDemo = model.demoEnabled
                        let now = model.planningNow, zone = model.planningTimeZone
                        Task { _ = await model.updatePlanning(expectedDemo: sourceIsDemo) { try $0.switchToManual(at: now, timeZoneID: zone) } }
                    }
                }
            } else { Text("先选择经验、活动、可用星期和单次上限；预览确认后才生效。").font(.caption).foregroundStyle(.secondary) }
            if let notice { Text(notice).font(.caption).foregroundStyle(.orange) }
            if !model.demoEnabled {
                Button("重读健康中的旧运动时段") { Task { await model.refresh(rebuildingWorkouts: true) } }
                    .disabled(model.busy || model.planningBusy)
                Text("旧缓存没有暂停/活跃时段时不会猜算分钟。需先在“我的”连接健康；重读不修改健康原始记录。").font(.caption2).foregroundStyle(.secondary)
            }
            Text("安排不由减重公斤数或截止天数反推。休息不补课，增加时长需预览确认。").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        .sheet(item: $draft) { AutomaticDraftForm(model: model, draft: $0) }
        .onChange(of: model.demoEnabled) { _, _ in draft = nil; notice = nil }
    }
    private func generateNext(_ week: GeneratedWeek) {
        do {
            var confirmed = 0, completed = 0
            for session in week.sessions {
                guard let entry = try model.displayedPlanning.scheduledEntry(at: session.day, timeZoneID: week.timeZoneID) else { continue }
                if entry.status == .rested { confirmed += 1 }
                else if entry.status == .completed || model.completion(for: entry, at: session.day)?.completed == true { confirmed += 1; completed += 1 }
            }
            if week.deadline != nil && model.displayedPlanning.goal?.status != .active {
                notice = "关联的减重目标已暂停；可恢复目标或重新生成不关联目标的活动计划。"
                return
            }
            draft = try AutomaticWeekPlanner.nextWeek(after: week, feedback: feedback, confirmedDays: confirmed, completedDays: completed,
                                                      now: model.planningNow, ending: week.deadline)
            notice = nil
        } catch { notice = "这一周尚未完整结束，或没有可调整的安排；不会自动加量。" }
    }
}

struct AutomaticPlanForm: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.dismiss) private var dismiss
    @State private var config: AutomaticPlanConfiguration
    @State private var typicalMinutes = ""
    @State private var start: Date
    @State private var draft: GeneratedWeek?
    @State private var notice: String?
    @State private var useGoalDeadline = false
    init(model: DashboardModel) {
        self.model = model
        let prior = model.displayedPlanning.automatic?.weeks.last?.configuration
        _config = State(initialValue: prior ?? AutomaticPlanConfiguration(experience: .starting, activities: [], weekdays: [], maximumMinutes: 30))
        _typicalMinutes = State(initialValue: prior?.typicalWeeklyMinutes.map(String.init) ?? "")
        _start = State(initialValue: (try? AnalysisClock(timeZoneID: model.planningTimeZone).shiftedDay(model.planningNow, by: 1)) ?? model.planningNow)
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.demoEnabled { Text("合成演示：不会写入真实计划").foregroundStyle(wristMint) }
                Section("你的可用条件") {
                    Picker("运动经验", selection: $config.experience) { ForEach(MovementExperience.allCases, id: \.self) { Text($0.title).tag($0) } }
                    Stepper("单次最多\(config.maximumMinutes)分钟", value: $config.maximumMinutes, in: 5...120, step: 5)
                    TextField("典型周运动分钟（可留空）", text: $typicalMinutes).keyboardType(.numberPad)
                    Text("留空时按经验生成初始草案，不能当成已观测历史。").font(.caption)
                    DatePicker("开始安排日期", selection: $start, in: tomorrow..., displayedComponents: .date)
                }
                Section("喜欢的活动（按列表顺序轮转）") {
                    ForEach(AutomaticActivity.allCases, id: \.self) { activity in
                        Toggle(activity.title, isOn: Binding(get: { config.activities.contains(activity) }, set: {
                            if $0 { config.activities = AutomaticActivity.allCases.filter { $0 == activity || config.activities.contains($0) } }
                            else { config.activities.removeAll { $0 == activity } }
                        }))
                    }
                }
                Section("可用星期") {
                    ForEach(Array(zip([2, 3, 4, 5, 6, 7, 1], ["周一", "周二", "周三", "周四", "周五", "周六", "周日"])), id: \.0) { weekday, title in
                        Toggle(title, isOn: Binding(get: { config.weekdays.contains(weekday) }, set: {
                            if $0 { config.weekdays.insert(weekday) } else { config.weekdays.remove(weekday) }
                        }))
                    }
                }
                if model.displayedPlanning.goal?.status == .active {
                    Section { Toggle("只安排到减重目标期望日期", isOn: $useGoalDeadline) }
                }
                Section {
                    Text("初版生成器最多安排150分钟/周，这是产品草案上限，不是安全额度或减脂保证；你可以在预览逐日调整。")
                    if let notice { Text(notice).foregroundStyle(.orange) }
                }.font(.caption)
                Button("生成周预览") { generate() }.disabled(model.busy || model.planningBusy)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("自动生成周计划")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .sheet(item: $draft) { AutomaticDraftForm(model: model, draft: $0) }
            .onChange(of: model.demoEnabled) { _, _ in dismiss() }
        }
    }
    private var tomorrow: Date { (try? AnalysisClock(timeZoneID: model.planningTimeZone).shiftedDay(model.planningNow, by: 1)) ?? model.planningNow }
    private func generate() {
        do {
            let text = typicalMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty || Int(text) != nil else { throw DomainError.invalidConfiguration }
            config.typicalWeeklyMinutes = text.isEmpty ? nil : Int(text)
            let goal = useGoalDeadline ? model.displayedPlanning.goal : nil
            let actualStart = max(start, goal?.start ?? start)
            draft = try AutomaticWeekPlanner.generate(config, starting: actualStart, timeZoneID: model.planningTimeZone, ending: goal?.deadline)
            notice = nil
        } catch { notice = "请至少选择一个活动和运动日；周基础至少5分钟，单次上限为5–120分钟。" }
    }
}

struct AutomaticDraftForm: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.dismiss) private var dismiss
    private let sourceIsDemo: Bool
    @State private var draft: GeneratedWeek
    init(model: DashboardModel, draft: GeneratedWeek) {
        self.model = model; sourceIsDemo = model.demoEnabled; _draft = State(initialValue: draft)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("周总量 \(draft.totalMinutes) 分钟").font(.headline)
                    Text(draft.explanation).font(.caption)
                    if let adjustment = draft.adjustment {
                        Text("基于已结束周：反馈\(adjustment.feedback.title)，确认\(adjustment.confirmedDays)天，其中完成\(adjustment.completedDays)天；原周量\(adjustment.previousMinutes)分钟。新总量仍需你采纳。").font(.caption)
                    }
                    if draft.sessions.isEmpty { Text("所选周期没有可安排日期，请调整开始日期、可用日或目标截止日期。").foregroundStyle(.orange) }
                }
                ForEach($draft.sessions) { $session in
                    Section(session.day.formatted(reportStyle(.dateTime.month().day().weekday(), draft.timeZoneID))) {
                        Picker("活动", selection: $session.activity) { ForEach(draft.configuration.activities, id: \.self) { Text($0.title).tag($0) } }
                        Stepper("\(session.minutes) 分钟", value: $session.minutes, in: 5...((draft.configuration.maximumMinutes / 5) * 5), step: 5)
                    }
                }
                Section {
                    Text("确认后仅更改未来未处理日，过去及已完成记录保留。逐日调整后总量仍不得超过150分钟。")
                    Text(draft.ruleVersion)
                    if let notice = model.planningNotice { Text(notice).foregroundStyle(.secondary) }
                }.font(.caption)
            }
            .navigationTitle("周计划预览")
            .onAppear { model.planningNotice = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回修改") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.planningBusy ? "保存中…" : "采纳计划") {
                        let now = model.planningNow, zone = model.planningTimeZone
                        Task { if await model.updatePlanning(expectedDemo: sourceIsDemo, { try $0.acceptAutomatic(draft, at: now, timeZoneID: zone) }) { dismiss() } }
                    }.disabled(model.planningBusy || model.busy || draft.sessions.isEmpty || (try? draft.validate()) == nil)
                }
            }
            .onChange(of: model.demoEnabled) { _, _ in dismiss() }
        }
    }
}
