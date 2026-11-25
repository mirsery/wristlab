import SwiftUI
import WristlabCore

struct WatchLocalSettingsView: View {
    @ObservedObject var model: WatchReportModel
    let demoEnabled: Bool
    @State private var timeZone = TimeZone.current.identifier
    @State private var sleepMinutes = 480
    @State private var usesMaximum = false
    @State private var maximumHeartRate = 180
    @State private var trainingMode = TrainingMode.maintain
    @State private var confirmTimeZone = false
    @State private var loaded = false
    var body: some View {
        Form {
            Section("手表独立设置") {
                Text("这些设置不会自动继承或同步到手机。未知最大心率请保持关闭。历史不足时仅显示实际校准进度。").font(.caption2)
                Picker("分析时区", selection: $timeZone) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                }
                Stepper("睡眠目标 \(sleepMinutes / 60)小时\(sleepMinutes % 60)分", value: $sleepMinutes, in: 240...720, step: 15)
                Toggle("已知最大心率", isOn: $usesMaximum)
                if usesMaximum { Stepper("最大心率 \(maximumHeartRate) bpm", value: $maximumHeartRate, in: 100...240) }
                Picker("训练模式", selection: $trainingMode) {
                    Text("轻松").tag(TrainingMode.easy)
                    Text("保持").tag(TrainingMode.maintain)
                    Text("提升").tag(TrainingMode.build)
                }
            }
            Section {
                Button("保存手表设置") {
                    if timeZone != model.profile.timeZoneID { confirmTimeZone = true }
                    else { Task { await save() } }
                }
                Button("连接手表健康并刷新") {
                    if timeZone != model.profile.timeZoneID { confirmTimeZone = true }
                    else { Task { await save(); if model.notice == nil { await model.connectLocal() } } }
                }
                Text(model.notice ?? model.status).font(.caption2)
            }
        }
        .disabled(!loaded || demoEnabled || model.busy || model.cleaning || model.envelope == nil)
        .navigationTitle("独立设置")
        .task {
            await model.prepareSettings()
            timeZone = model.profile.timeZoneID
            sleepMinutes = model.profile.sleepTargetMinutes
            usesMaximum = model.profile.maximumHeartRate != nil
            maximumHeartRate = Int(model.profile.maximumHeartRate ?? 180)
            trainingMode = model.profile.trainingMode
            loaded = true
        }
        .alert("更改分析时区？", isPresented: $confirmTimeZone) {
            Button("更改并重算") { Task { await save() } }
            Button("取消", role: .cancel) {}
        } message: { Text("分析日与历史基线会按新时区重新计算；不会自动跟随设备时区变化。保存后可再连接手表健康。") }
    }
    @MainActor private func save() async {
        var profile = model.profile
        profile.timeZoneID = timeZone
        profile.sleepTargetMinutes = sleepMinutes
        profile.maximumHeartRate = usesMaximum ? Double(maximumHeartRate) : nil
        profile.trainingMode = trainingMode
        await model.configure(profile)
    }
}
