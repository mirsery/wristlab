import SwiftUI
import WristlabCore

enum WatchPage: Hashable { case metric(ComplicationMetric), guide, settings }

@main
struct WristlabWatchApp: App {
    @StateObject private var bridge: WatchBridge
    @StateObject private var model: WatchReportModel
    @StateObject private var care: WatchCareModel
    @State private var demoReport: HealthReport?
    @State private var demoEnabled = ProcessInfo.processInfo.arguments.contains("--demo")
    @State private var menu = false
    @State private var path: [WatchPage] = []
    @State private var tab = WatchCareTab.care
    @State private var externalRouteReceived = false
    @State private var confirmStop = false
    @State private var confirmActivityStop = false
    @Environment(\.scenePhase) private var phase
    init() {
        let bridge = WatchBridge()
        let model = WatchRuntime.makeModel(phone: bridge.snapshot)
        let care = WatchRuntime.makeCareModel(report: model)
        bridge.onSnapshotReceived = { [weak model] in model?.receivePhone($0) }
        _bridge = StateObject(wrappedValue: bridge)
        _model = StateObject(wrappedValue: model)
        _care = StateObject(wrappedValue: care)
        if ProcessInfo.processInfo.arguments.contains("--demo"),
           let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--demo-page=") }),
           let page = WatchCarePage(rawValue: String(argument.dropFirst("--demo-page=".count))) {
            _tab = State(initialValue: page)
        }
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                TimelineView(.periodic(from: .now, by: 60)) { tick in
                    WatchCareDashboard(model: model, care: care, bridge: bridge, demoReport: demoEnabled ? demoReport : nil,
                        demoEnabled: demoEnabled, now: demoEnabled ? (demoReport?.asOf ?? DemoData.previewDate) : tick.date, tab: $tab)
                }
                .navigationTitle(tab.title).navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: WatchPage.self) { page in
                    switch page {
                    case .guide: WatchFaceGuideView()
                    case .settings: WatchLocalSettingsView(model: model, demoEnabled: demoEnabled)
                    case .metric(let metric): WatchCareMetricDetail(model: model, demo: demoEnabled ? demoReport : nil, metric: metric)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { menu = true } label: { Image(systemName: "ellipsis").foregroundStyle(wristBackground) }.accessibilityLabel("更多")
                    }
                }
                .sheet(isPresented: $menu) { menuContent }
            }
            .tint(wristMint)
            .alert("停止并清除手表本地数据？", isPresented: $confirmStop) {
                Button("停止并清除", role: .destructive) { Task { await model.stopLocal() } }
                Button("取消", role: .cancel) {}
            } message: { Text("清除手表本地评分、日常活动缓存和自报心情；保留手机同步副本，不删除Apple健康原始记录。重新读取需主动连接。") }
            .alert("停止日常活动读取？", isPresented: $confirmActivityStop) {
                Button("停止活动读取", role: .destructive) { do { try care.stopActivity() } catch {} }
                Button("取消", role: .cancel) {}
            } message: { Text("只清除步数和圆环缓存，保留自报心情与状态报告。") }
            .onChange(of: phase) { _, value in
                if value == .active, !demoEnabled { Task { await model.foreground(); await care.foreground() } }
            }
            .onChange(of: model.envelope?.mode) { _, _ in path = []; care.invalidate() }
            .onChange(of: model.profile.version) { _, _ in path = []; care.invalidate() }
            .onOpenURL { url in
                externalRouteReceived = true; demoEnabled = false; care.setDemo(false); menu = false
                Task { await model.setDemo(false) }
                let destination = ComplicationDestination(url: url)
                tab = WatchCarePage.destination(for: destination)
                path = destination.metric.map { [.metric($0)] } ?? []
            }
            .task {
                if demoEnabled, !externalRouteReceived { await loadDemo() }
                else { await model.start(); await care.foreground() }
                if ProcessInfo.processInfo.arguments.contains("--face-guide"), !externalRouteReceived { path = [.guide] }
            }
        }
    }
    private var menuContent: some View {
        List {
            Section("页面") {
                ForEach(WatchCareTab.allCases) { page in Button(page.title) { tab = page; menu = false } }
            }
            Button("表盘组件") { menu = false; path = [.guide] }
            if !demoEnabled {
                Section("状态报告来源") {
                    sourceSummary("手表本地", snapshot: model.localSnapshot)
                    Button("手表本地计算") { Task { await model.select(.local) }; menu = false }
                    sourceSummary("手机同步", snapshot: model.phoneSnapshot)
                    Button("手机同步") { Task { await model.select(.phone) }; menu = false }
                }.disabled(model.envelope == nil || model.cleaning)
                Button("手表独立设置与连接") { menu = false; path = [.settings] }
                if model.envelope?.mode == .local {
                    Button("刷新手表本地报告") { Task { await model.refreshLocal() }; menu = false }
                        .disabled(model.busy || model.envelope?.localState != .enabled)
                } else { Button("请求手机刷新") { bridge.requestRefresh(); menu = false } }
                Button(care.activityEnabled ? "刷新日常活动" : "连接日常活动") {
                    menu = false; Task { if care.activityEnabled { await care.refresh() } else { await care.connect() } }
                }.disabled(care.busy || model.envelope == nil || model.envelope?.cleanupPending == true)
                if care.activityEnabled { Button("停止日常活动读取", role: .destructive) { menu = false; confirmActivityStop = true } }
                Button("停止手表读取并清除本地数据", role: .destructive) { menu = false; confirmStop = true }
                    .disabled(model.envelope == nil || model.cleaning)
                if bridge.pendingProducer != nil { Button("确认连接新手机") { bridge.confirmProducer() } }
            }
            Button(demoEnabled ? "退出演示" : "查看合成演示") {
                path = []; menu = false
                if demoEnabled { demoEnabled = false; care.setDemo(false); Task { await model.setDemo(false); await care.foreground() } }
                else { Task { await loadDemo() } }
            }
        }
    }
    @MainActor private func loadDemo() async {
        demoEnabled = true; care.setDemo(true); await model.setDemo(true)
        if demoReport == nil {
            let report = try? await Task.detached { try DemoData.report() }.value
            if demoEnabled { demoReport = report }
        }
    }
    private func sourceSummary(_ title: String, snapshot: DisplaySnapshot?) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            if let snapshot { Text(snapshot.computedAt, style: .time).font(.caption2) }
            else { Text("暂无报告").font(.caption2) }
        }
    }
}
