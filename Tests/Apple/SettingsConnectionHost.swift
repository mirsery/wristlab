import SwiftUI

let wristMint = Color.mint

struct WatchFaceGuideView: View {
    var body: some View { Text("合成测试未覆盖表盘设置") }
}

@main struct SettingsConnectionHost: App {
    @StateObject private var model: DashboardModel
    private let reader: HealthKitReader
    init() {
        let reader = HealthKitReader()
        reader.holdAuthorization = true
        reader.holdReads = true
        if CommandLine.arguments.contains("--synthetic-authorization-failure") {
            reader.holdAuthorization = false
            reader.authorizationFailure = true
        }
        self.reader = reader
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-settings-\(UUID())/health.json")
        let model = DashboardModel(reader: reader, repositoryFile: file, clearNotifications: {})
        model.morningBriefEnabled = false
        model.moodConnected = false
        model.demoEnabled = CommandLine.arguments.contains("--synthetic-demo")
        _model = StateObject(wrappedValue: model)
    }
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                Text("合成设置验证 · 无真实健康数据").font(.caption)
                HStack {
                    Button("合成读取阶段") {
                        reader.holdAuthorization = false
                        reader.releaseAuthorization()
                    }.accessibilityIdentifier("fixture.read")
                    Button("合成完成") {
                        reader.holdReads = false
                        reader.releaseReads()
                    }.accessibilityIdentifier("fixture.finish")
                }.buttonStyle(.bordered)
                SettingsView(model: model)
            }
        }
    }
}
