import SwiftUI
import WristlabCore

struct SettingsView: View {
    @ObservedObject var model: DashboardModel
    @State private var profile: HealthProfile
    @State private var maximum: String
    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss
    init(model: DashboardModel) {
        self.model = model
        _profile = State(initialValue: model.profile)
        _maximum = State(initialValue: model.profile.maximumHeartRate.map { String(Int($0)) } ?? "")
    }
    private var candidate: HealthProfile {
        var result = profile
        result.maximumHeartRate = maximum.isEmpty ? nil : Double(maximum) ?? .nan
        return result
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("个人偏好") {
                    TextField("分析时区", text: $profile.timeZoneID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("时区保持固定；旅行时不会静默更改历史日期。").font(.caption).foregroundStyle(.secondary)
                    Stepper("睡眠目标 \(profile.sleepTargetMinutes / 60) 小时 \(profile.sleepTargetMinutes % 60) 分", value: $profile.sleepTargetMinutes, in: 240...720, step: 15)
                    TextField("最大心率（可留空，100–240）", text: $maximum).keyboardType(.decimalPad)
                    Picker("训练模式", selection: $profile.trainingMode) {
                        Text("轻松").tag(TrainingMode.easy); Text("维持").tag(TrainingMode.maintain); Text("发展").tag(TrainingMode.build)
                    }
                }
                Section("数据来源优先级") {
                    ForEach(HealthKind.allCases, id: \.self) { kind in
                        Picker(sourceTitle(kind), selection: Binding(get: { profile.preferredSources[kind]?.first ?? "" }, set: { profile.preferredSources[kind] = $0.isEmpty ? [] : [$0] })) {
                            Text("自动选择").tag("")
                            ForEach(model.sources[kind] ?? [], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                Section("睡眠标记") {
                    Toggle("当前睡眠窗口确实未睡", isOn: Binding(get: { profile.confirmedNoSleepDays.contains(todayLabel) }, set: {
                        if $0 { profile.confirmedNoSleepDays.insert(todayLabel) } else { profile.confirmedNoSleepDays.remove(todayLabel) }
                    }))
                    Text("仅用于区分未观测和确实未睡。后续健康记录到达时以实际记录为准，不写入 Apple 健康。").font(.caption).foregroundStyle(.secondary)
                }
                Section("连接与演示") {
                    Button { Task { await model.connect() } } label: {
                        HStack {
                            Text(model.busy ? "健康请求处理中…" : "连接 / 检查 Apple 健康")
                            Spacer()
                            if model.busy { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(model.busy || model.demoEnabled)
                    .accessibilityIdentifier("settings.health.connect")
                    .accessibilityValue(model.demoEnabled ? "合成演示中，暂不连接" : model.busy ? model.status : "可连接")
                    if model.demoEnabled {
                        Text("当前为合成演示，请先在首页退出演示，再连接真实健康记录。")
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.health.demo")
                    } else {
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.health.status")
                    }
                    Button("刷新数据") { Task { await model.refresh() } }
                        .disabled(model.busy || model.demoEnabled)
                        .accessibilityIdentifier("settings.health.refresh")
                    Button("打开合成演示") { dismiss(); Task { await model.enableDemo() } }
                        .disabled(model.busy)
                }
                Section {
                    Toggle("推送晨报", isOn: Binding(get: { model.morningBriefEnabled }, set: { value in Task { await model.setMorningBrief(enabled: value) } }))
                    Toggle("通知中隐藏数值", isOn: Binding(get: { !model.morningBriefShowsValues }, set: { model.setMorningBrief(showValues: !$0) }))
                        .disabled(!model.morningBriefEnabled)
                } header: { Text("晨报通知") } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let notice = model.morningBriefNotice { Text(notice).foregroundStyle(.orange) }
                        Text("每天5:00–14:00之间（分析时区），刷新得到今天已完成的主睡眠后发送一次。送达时间取决于系统后台机会和打开应用的时间，不固定。显示数值时，数值会出现在锁屏和通知中心，系统也可能转发到配对的Apple Watch；隐藏数值时只提示主睡眠已汇总。清除数据会撤回已送达的晨报。")
                    }
                }
                Section("Apple Watch") {
                    NavigationLink("表盘组件") { WatchFaceGuideView() }
                }
                Section("本地数据") {
                    Button("清除派生缓存并重算") { Task { await model.clear(stop: false) } }
                    Text("重算保留运动计划、执行记录、减重目标与手动体重。").font(.caption).foregroundStyle(.secondary)
                    Button("停止读取并清除应用数据", role: .destructive) { confirmClear = true }
                    Text("不会删除 Apple 健康原始记录。离线的手表会在下次连接时接收清除标记。").font(.caption).foregroundStyle(.secondary)
                }
                Section { Text(model.status).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("设置")
            .task { await model.checkMorningBriefPermission() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await model.save(candidate); dismiss() } }.disabled(model.busy || (try? candidate.validate()) == nil) }
            }
            .alert("停止读取并清除？", isPresented: $confirmClear) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) { Task { await model.clear(stop: true) } }
            } message: { Text("清除本机健康缓存、运动计划、执行记录、减重目标和手动体重，并清除手表中的手机同步副本；不会删除手表独立记录或 Apple 健康原始记录。") }
        }.tint(wristMint)
    }
    private var todayLabel: String { (try? AnalysisClock(timeZoneID: profile.timeZoneID).label(Date())) ?? "" }
    private func sourceTitle(_ kind: HealthKind) -> String {
        switch kind { case .heartRate: "心率"; case .restingHeartRate: "静息心率"; case .hrv: "HRV"; case .sleep: "睡眠"; case .workout: "运动" }
    }
}
