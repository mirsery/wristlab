import SwiftUI
import WristlabCore

@main
struct WristlabWatchApp: App {
    @StateObject private var bridge = WatchBridge()
    @State private var demo: DisplaySnapshot?
    @State private var demoEnabled = false
    @State private var menu = false
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    let current = demoEnabled ? demo : bridge.snapshot
                    VStack(spacing: 10) {
                        Text("WRISTLAB").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(wristMint)
                        if demoEnabled { Text("合成演示数据").font(.system(size: 9)).foregroundStyle(.secondary) }
                        if let current, !current.clearData {
                            Text("训练准备度").font(.caption2).foregroundStyle(.secondary)
                            ScoreRing(value: current.readiness.value, size: 84)
                            HStack {
                                watchMetric("电量", current.energy, .cyan, at: demoEnabled ? current.asOf : Date())
                                Spacer()
                                watchMetric("压力", current.stress, .orange, at: demoEnabled ? current.asOf : Date())
                            }.padding(.horizontal, 12)
                            Text(metricStatus(current.readiness, at: demoEnabled ? current.asOf : Date())).font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(current.computedAt, style: .time).font(.system(size: 9)).foregroundStyle(.secondary)
                            if current.isStale(at: Date()), !demoEnabled { Text("快照已过期").font(.caption2).foregroundStyle(.orange) }
                        } else {
                            Image(systemName: "iphone.and.arrow.forward").font(.title).foregroundStyle(wristMint).padding(.vertical, 18)
                            Text("在手机连接 Apple 健康").font(.footnote)
                            Text(bridge.status).font(.caption2).foregroundStyle(.secondary)
                        }
                        if bridge.pendingProducer != nil { Button("确认连接新手机") { bridge.confirmProducer() } }
                    }.padding(.vertical, 8)
                }
                .background(wristBackground)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { menu = true } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多") } }
                .sheet(isPresented: $menu) {
                    List {
                        Button("请求手机刷新") { bridge.requestRefresh(); menu = false }
                        Button(demoEnabled ? "退出演示" : "查看合成演示") {
                            if demoEnabled { demoEnabled = false; menu = false }
                            else { Task { await loadDemo(); menu = false } }
                        }
                        Text(bridge.status).font(.caption2)
                    }
                }
            }
            .tint(wristMint)
            .task { if ProcessInfo.processInfo.arguments.contains("--demo") { await loadDemo() } }
        }
    }
    @MainActor private func loadDemo() async {
        demoEnabled = true
        if demo == nil, let report = try? await Task.detached(operation: { try DemoData.report() }).value {
            demo = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
        }
    }
    private func watchMetric(_ title: String, _ metric: MetricEstimate, _ color: Color, at now: Date) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(color)
            Text(metric.value.map(String.init) ?? "—").font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
            if metric.isStale(at: now) { Text("过期").font(.system(size: 8)).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
