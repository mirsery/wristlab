import SwiftUI
import WristlabCore

private enum WatchPage: Hashable { case metric(ComplicationMetric), guide }

@main
struct WristlabWatchApp: App {
    @StateObject private var bridge = WatchBridge()
    @State private var demo: DisplaySnapshot?
    @State private var demoEnabled = false
    @State private var menu = false
    @State private var path: [WatchPage] = []
    @State private var externalRouteReceived = false
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                GeometryReader { geometry in
                ScrollView {
                    let current = demoEnabled ? demo : bridge.snapshot
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("WRISTLAB").font(.system(size: 8, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(wristMint)
                            if demoEnabled { Text("合成演示数据").font(.system(size: 8)).foregroundStyle(.secondary) }
                        }
                        if let current, !current.clearData {
                            let readiness = ComplicationPresentation(snapshot: current, metric: .readiness, at: context.date)
                            Text("训练准备度").font(.system(size: 10)).foregroundStyle(.secondary)
                            NavigationLink(value: WatchPage.metric(.readiness)) {
                                ScoreRing(value: demoEnabled ? current.readiness.value : readiness.value, size: 64)
                            }.buttonStyle(.plain)
                            HStack {
                                NavigationLink(value: WatchPage.metric(.energy)) { watchMetric(.energy, snapshot: current, color: .cyan, at: context.date) }.buttonStyle(.plain)
                                NavigationLink(value: WatchPage.metric(.stress)) { watchMetric(.stress, snapshot: current, color: .orange, at: context.date) }.buttonStyle(.plain)
                            }.padding(.horizontal, 12)
                            if !demoEnabled { Text(readiness.statusText).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(2) }
                            Text(current.computedAt, style: .time).font(.system(size: 8)).foregroundStyle(.secondary)
                            if current.isStale(at: context.date), !demoEnabled { Text("快照已过期").font(.caption2).foregroundStyle(.orange) }
                        } else {
                            Image(systemName: "iphone.and.arrow.forward").font(.title).foregroundStyle(wristMint).padding(.vertical, 18)
                            Text("在手机连接 Apple 健康").font(.footnote)
                            Text(bridge.status).font(.caption2).foregroundStyle(.secondary)
                        }
                        if bridge.pendingProducer != nil { Button("确认连接新手机") { bridge.confirmProducer() } }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(wristBackground.ignoresSafeArea())
                }
                }
                .navigationDestination(for: WatchPage.self) { page in
                    switch page {
                    case .guide: WatchFaceGuideView()
                    case .metric(let metric):
                        WatchMetricDetail(bridge: bridge, demo: demoEnabled ? demo : nil, metric: metric)
                    }
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { menu = true } label: { Image(systemName: "ellipsis").foregroundStyle(.white) }.tint(.gray).accessibilityLabel("更多") } }
                .sheet(isPresented: $menu) {
                    List {
                        Button("表盘组件") { menu = false; path = [.guide] }
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
            .onOpenURL { url in
                externalRouteReceived = true
                demoEnabled = false
                menu = false
                let destination = ComplicationDestination(url: url)
                path = destination.metric.map { [.metric($0)] } ?? []
            }
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--demo"), !externalRouteReceived { await loadDemo() }
                if arguments.contains("--face-guide"), !externalRouteReceived { path = [.guide] }
            }
        }
    }
    @MainActor private func loadDemo() async {
        demoEnabled = true
        if demo == nil, let report = try? await Task.detached(operation: { try DemoData.report() }).value {
            guard demoEnabled else { return }
            demo = DisplaySnapshot(report: report, producerID: "synthetic", epoch: 0, sequence: 0)
        }
    }
    private func watchMetric(_ metric: ComplicationMetric, snapshot: DisplaySnapshot, color: Color, at now: Date) -> some View {
        let display = ComplicationPresentation(snapshot: snapshot, metric: metric, at: now)
        let value = demoEnabled ? metric.estimate(in: snapshot).value : display.value
        return VStack(spacing: 2) {
            Text(metric.shortTitle).font(.system(size: 9)).foregroundStyle(color)
            Text(value.map(String.init) ?? "—").font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
            if !demoEnabled, display.state != .current {
                Text(display.statusText).font(.system(size: 8)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}


private struct WatchMetricDetail: View {
    @ObservedObject var bridge: WatchBridge
    let demo: DisplaySnapshot?
    let metric: ComplicationMetric
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let display = ComplicationPresentation(snapshot: bridge.snapshot, metric: metric, at: context.date)
            let demoEstimate = demo.map { metric.estimate(in: $0) }
            ScrollView {
                VStack(spacing: 12) {
                    if demo != nil { Label("合成演示数据", systemImage: "sparkles").font(.caption2).foregroundStyle(wristMint) }
                    Label(metric.title, systemImage: metric.symbol).font(.headline)
                    ScoreRing(value: demoEstimate?.value ?? display.value, size: 90).padding(.vertical, 8)
                    Text(demo.map { metricStatus(metric.estimate(in: $0), at: $0.asOf) } ?? display.statusText).font(.caption2).foregroundStyle(.secondary)
                    if demo == nil {
                        Text(display.detailText).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let date = demo?.computedAt ?? display.updatedAt {
                        Text("最近更新").font(.caption2).foregroundStyle(.secondary)
                        Text(date, style: .time).font(.caption2)
                    }
                    if demo == nil { Button("请求手机刷新") { bridge.requestRefresh() }; Text(bridge.status).font(.caption2).foregroundStyle(.secondary) }
                }.padding()
            }.background(wristBackground)
        }
        .environment(\.timeZone, TimeZone(identifier: (demo ?? bridge.snapshot)?.timeZoneID ?? "") ?? .current)
        .navigationTitle(metric.shortTitle)
    }
}
