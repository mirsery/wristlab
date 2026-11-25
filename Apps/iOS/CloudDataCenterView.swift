import SwiftUI
import WristlabCore

struct CloudDataCenterView: View {
    @ObservedObject var cloud: CloudPreferencesModel
    @ObservedObject var model: DashboardModel
    @State private var confirmation: Confirmation?
    private enum Confirmation: String, Identifiable {
        case enable, clearLocal, deleteCloud
        var id: String { rawValue }
    }
    private var accountAvailable: Bool {
        if case .available = cloud.state?.account { return true }
        return false
    }
    var body: some View {
        Form {
            Section("当前iCloud账户") {
                Text(cloud.state?.account.title ?? "尚未检查账户")
                Text("使用系统当前账户，不另设登录，不读取或显示Apple ID邮箱、姓名和头像。").font(.caption).foregroundStyle(.secondary)
                Button("检查账户与同步状态") { Task { await cloud.checkAccount() } }
                    .disabled(cloud.working)
            }
            if model.demoEnabled {
                Section { Text("合成演示期间云同步已暂停，不上传演示选择。").foregroundStyle(wristMint) }
            }
            Section("界面偏好同步") {
                Text(cloud.state?.phase.title ?? "同步未开启")
                if cloud.working {
                    ProgressView("正在处理")
                    Button("停止本次同步并关闭") { Task { await cloud.disable() } }
                }
                if let state = cloud.state {
                    Text("待上传：\(state.pending ? 1 : 0)份界面偏好").font(.caption)
                    if let date = state.lastSuccess { Text("最近确认：\(date.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                    if state.deletionPending { Text("云端删除尚未确认；请联网后再次确认删除，不会自动重建偏好。").foregroundStyle(.orange) }
                    if let retry = state.retryNotBefore, retry > Date() {
                        Text("服务端要求稍后重试：\(retry.formatted(date: .abbreviated, time: .shortened))之后才会再次请求。").font(.caption).foregroundStyle(.orange)
                    }
                }
                if cloud.state?.enabled == true {
                    Button("立即同步") { Task { await cloud.synchronize() } }.disabled(cloud.working)
                    Button("关闭同步，保留本机与云端") { Task { await cloud.disable() } }
                } else {
                    Button("开启界面偏好同步") { confirmation = .enable }.disabled(cloud.working || !accountAvailable || cloud.state?.deletionPending == true)
                }
                Text("仅同步：趋势主题、健康图表指标、健康图表7/30日、运动图表7/30日。不含任何健康数值、体重、目标、运动计划或执行记录。").font(.caption).foregroundStyle(.secondary)
            }
            if cloud.state?.phase == .choice || cloud.state?.phase == .conflict {
                Section("恢复或解决冲突") {
                    Text("未自动覆盖任何一份。请核对后选择；上传前仍会检查云端版本。").font(.caption)
                    preferenceRows("本机", cloud.preferences)
                    if let remote = cloud.state?.remote {
                        if let preferences = remote.preferences { preferenceRows("云端", preferences) }
                        else { Text("云端保存了删除标记；明确上传才会重新建立偏好。").font(.caption) }
                        Button(remote.deleted ? "遵循云端删除，保持暂停" : "恢复云端界面偏好") { Task { await cloud.resolve(.cloud) } }
                    } else { Text("尚无可恢复的云端偏好；可确认创建，或取消。").font(.caption) }
                    Button("确认使用本机偏好并上传") { Task { await cloud.resolve(.local) } }
                    Button("取消，关闭同步") { Task { await cloud.resolve(.cancel) } }
                }.disabled(cloud.working)
            }
            Section("换机恢复范围") {
                Text("同一iCloud账户可恢复上述界面偏好；开发/生产云环境相互独立，不保证立即同步。").font(.caption)
                Text("健康原始记录由Apple健康自身同步，新机需主动连接健康并等待历史到达。体重、减重目标、计划与执行历史目前仍只在本机，不支持云恢复。").font(.caption).foregroundStyle(.secondary)
            }
            Section("数据管理") {
                Button("清除本机界面偏好", role: .destructive) { confirmation = .clearLocal }
                Button("删除云端界面偏好", role: .destructive) { confirmation = .deleteCloud }.disabled(cloud.working || !accountAvailable)
                Text("只操作界面偏好。健康缓存、运动计划和体重的本地清除仍在设置中，均不删除Apple健康原始记录。").font(.caption).foregroundStyle(.secondary)
            }
            if let notice = cloud.notice { Section("说明") { Text(notice).foregroundStyle(.orange) } }
        }
        .disabled(model.demoEnabled)
        .navigationTitle("iCloud与数据中心").navigationBarTitleDisplayMode(.inline)
        .task { await cloud.checkAccount() }
        .onChange(of: model.demoEnabled) { _, _ in confirmation = nil }
        .onChange(of: cloud.state?.account) { _, _ in confirmation = nil }
        .alert(item: $confirmation) { action in
            switch action {
            case .enable:
                Alert(title: Text("只同步四项界面偏好？"), message: Text("不上传健康、体重、目标或计划；先检查云端，再由你选择恢复或上传。"), primaryButton: .default(Text("继续"), action: { Task { await cloud.enable() } }), secondaryButton: .cancel())
            case .clearLocal:
                Alert(title: Text("清除本机界面偏好？"), message: Text("暂停同步并清除本机各账户的界面偏好缓存和待传队列，恢复默认界面。不主动删除云端、健康、计划或体重；已经发出的云操作不能撤销。"), primaryButton: .destructive(Text("清除"), action: { Task { await cloud.disable(clearLocal: true) } }), secondaryButton: .cancel())
            case .deleteCloud:
                Alert(title: Text("删除当前账户的云端界面偏好？"), message: Text("写入删除标记并暂停同步，本机偏好仍保留。其他设备旧副本不会自动上传复活；重新建立需明确开启。"), primaryButton: .destructive(Text("删除云端偏好"), action: { Task { await cloud.deleteCloud() } }), secondaryButton: .cancel())
            }
        }
    }
    private func preferenceRows(_ title: String, _ preferences: InterfacePreferences) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text("主题：\(TrendsSection(rawValue: preferences.section)?.title ?? "未知") · 指标：\(TrendMetric(rawValue: preferences.metric)?.title ?? "未知")")
            Text("健康图表\(preferences.healthDays)日 · 运动图表\(preferences.movementDays)日")
        }.font(.caption)
    }
}
