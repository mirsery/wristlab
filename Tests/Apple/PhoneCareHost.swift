import SwiftUI
import WristlabCore

@main struct PhoneCareHost: App {
    @State private var report: HealthReport?
    private let largeType = CommandLine.arguments.contains("--large-type")
    private let frozen = CommandLine.arguments.contains("--demo-freeze")

    init() {
        if CommandLine.arguments.contains("--missing") { _report = State(initialValue: nil); return }
        var synthetic = try? DemoData.report()
        let now = ProcessInfo.processInfo.environment["PHONE_CARE_FIXTURE_NOW"].flatMap(Double.init)
            .map { Date(timeIntervalSince1970: $0) } ?? Date()
        synthetic?.source = CommandLine.arguments.contains("--demo-freeze") ? .demo : .healthKit
        synthetic?.asOf = now.addingTimeInterval(-5400)
        let deadline = now.addingTimeInterval(3600)
        let contributions = ["hrv": 55.0, "baselineHRV": 50, "zHRV": 0.7, "rhr": 58, "baselineRHR": 60, "zRHR": 0.5]
        synthetic?.readiness = MetricEstimate(50, baselineDays: 18, mode: "night",
            contributions: contributions, effectiveAt: now.addingTimeInterval(-7200), validUntil: deadline)
        synthetic?.energy.estimate = MetricEstimate(0, mode: "energy", effectiveAt: now.addingTimeInterval(-7200), validUntil: deadline)
        synthetic?.stress = MetricEstimate(83, quality: .partial, reasons: ["hrOnly"], mode: "awake",
            effectiveAt: now.addingTimeInterval(-7200), validUntil: deadline)
        if CommandLine.arguments.contains("--mixed-heights") {
            synthetic?.energy.estimate = MetricEstimate(availability: .calibrating, reasons: ["baselineNotReady"],
                baselineDays: 9, mode: "energy", effectiveAt: now.addingTimeInterval(-7200), validUntil: deadline)
            synthetic?.stress = MetricEstimate(40, mode: "awake", effectiveAt: now.addingTimeInterval(-7200), validUntil: deadline)
        }
        _report = State(initialValue: synthetic)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("合成关怀验证 · 无真实健康数据")
                        if frozen { Text("合成演示 · 非健康评估") }
                        #if LEGACY_CARE_PROBE
                        NavigationLink {
                            Text("旧卡片验证")
                        } label: {
                            SmallMetricCard(kind: .energy, title: "身体电量", symbol: "battery.75percent",
                                metric: report?.energy.estimate ?? MetricEstimate(), color: .cyan, now: Date())
                        }.accessibilityIdentifier("care.energy")
                        #else
                        PhoneCareSection(report: report, demo: frozen)
                        #endif
                    }.padding(22)
                }
                #if !LEGACY_CARE_PROBE
                .navigationDestination(for: ComplicationMetric.self) { kind in
                    PhoneCareClock(demoDate: frozen ? report?.asOf : nil) { now in
                        MetricDetailView(kind: kind, title: kind.title, metric: estimate(kind), report: report, now: now)
                    }
                }
                #endif
                .navigationTitle("今天")
                .background(wristBackground)
            }
            .safeAreaInset(edge: .bottom) {
                if CommandLine.arguments.contains("--expires") {
                    Button("开始过期测试") {
                        let deadline = Date().addingTimeInterval(2)
                        report?.readiness.validUntil = deadline
                        report?.energy.estimate.validUntil = deadline
                        report?.stress.validUntil = deadline
                    }.buttonStyle(.bordered).accessibilityIdentifier("fixture.expire")
                }
            }
            .preferredColorScheme(.dark)
            .environment(\.dynamicTypeSize, largeType ? .accessibility5 : .large)
        }
    }

    private func estimate(_ kind: ComplicationMetric) -> MetricEstimate {
        switch kind {
        case .readiness: report?.readiness ?? MetricEstimate()
        case .energy: report?.energy.estimate ?? MetricEstimate()
        case .stress: report?.stress ?? MetricEstimate()
        }
    }
}
