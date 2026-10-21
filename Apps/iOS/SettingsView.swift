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
                    Button("连接 / 检查 Apple 健康") { Task { await model.connect() } }
                    Button("刷新数据") { Task { await model.refresh() } }
                    Button("打开合成演示") { dismiss(); Task { await model.enableDemo() } }
                }
                Section("本地数据") {
                    Button("清除派生缓存并重算") { Task { await model.clear(stop: false) } }
                    Button("停止读取并清除应用数据", role: .destructive) { confirmClear = true }
                    Text("不会删除 Apple 健康原始记录。离线的手表会在下次连接时接收清除标记。").font(.caption).foregroundStyle(.secondary)
                }
                Section { Text(model.status).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await model.save(candidate); dismiss() } }.disabled(model.busy || (try? candidate.validate()) == nil) }
            }
            .alert("停止读取并清除？", isPresented: $confirmClear) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) { Task { await model.clear(stop: true) } }
            } message: { Text("清除本机应用健康缓存，并通知配对手表。Apple 健康中的原始记录会保留。") }
        }.tint(wristMint)
    }
    private var todayLabel: String { (try? AnalysisClock(timeZoneID: profile.timeZoneID).label(Date())) ?? "" }
    private func sourceTitle(_ kind: HealthKind) -> String {
        switch kind { case .heartRate: "心率"; case .restingHeartRate: "静息心率"; case .hrv: "HRV"; case .sleep: "睡眠"; case .workout: "运动" }
    }
}
