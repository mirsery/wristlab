import SwiftUI
import WidgetKit
import WristlabCore

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: DisplaySnapshot?
    var mode: WatchReportMode? = nil
    var daily: DailyActivityReport? = nil
    var originShort: String { mode.map { $0 == .local ? "表" : "机" } ?? "未选" }
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let display = read()
        completion(Entry(date: Date(), snapshot: display?.snapshot, mode: display?.mode, daily: display?.careProjection?.daily))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date(), display = read()
        let daily = display?.careProjection?.daily
        let dates = Array(Set(ComplicationTimeline.dates(snapshot: display?.snapshot, now: now) +
            CareActivityTimeline.dates(daily: daily, now: now, timeZoneID: TimeZone.current.identifier))).sorted()
        let entries = dates.map { Entry(date: $0, snapshot: display?.snapshot, mode: display?.mode, daily: daily) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(900))))
    }
    private func read() -> WatchDisplayEnvelope? {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mirsery.wristlab.watch")
        guard let folder else { return nil }
        let file = folder.appendingPathComponent("watch-display-v1.json")
        if FileManager.default.fileExists(atPath: file.path) {
            guard let data = try? Data(contentsOf: file) else { return nil }
            return WatchDisplayCache.read(displayData: data, legacyPhoneData: nil)
        }
        return WatchDisplayCache.read(displayData: nil, legacyPhoneData: try? Data(contentsOf: folder.appendingPathComponent("watch-receiver.json")))
    }
}
private extension ComplicationMetric {
    var configurationTitle: LocalizedStringKey {
        switch self { case .energy: "Wristlab 身体电量"; case .readiness: "Wristlab 训练准备度"; case .stress: "Wristlab 生理压力" }
    }
    var destination: ComplicationDestination {
        switch self { case .energy: .energy; case .readiness: .readiness; case .stress: .stress }
    }
}
struct MetricComplicationView: View {
    let entry: Entry
    let metric: ComplicationMetric
    @Environment(\.widgetFamily) private var family
    private var display: CareMetricPresentation { CareMetricPresentation(snapshot: entry.snapshot, metric: metric, at: entry.date) }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("\(entry.originShort) · \(metric.shortTitle) · \(display.title)", systemImage: display.symbol)
            case .accessoryCircular:
                VStack(spacing: 3) {
                    metricSymbol.font(.title3).widgetAccentable()
                    Text(shortState(display)).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                }.widgetLabel { Text("\(entry.originShort) · \(metric.shortTitle)") }
            case .accessoryCorner:
                metricSymbol.font(.title2).widgetAccentable()
                    .widgetLabel { Text("\(entry.originShort) · \(metric.shortTitle) · \(display.title)") }
            default:
                HStack(spacing: 8) {
                    metricSymbol.font(.title2).widgetAccentable()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.originShort) · \(metric.title)").font(.caption2)
                        Text(display.title).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                        if let note = display.inputNote { Text(note).font(.caption2) }
                        if let date = entry.snapshot?.computedAt { Text(date, style: .time).font(.caption2).foregroundStyle(.secondary) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .environment(\.timeZone, TimeZone(identifier: entry.snapshot?.timeZoneID ?? "") ?? .current)
        .widgetURL(metric.destination.url).privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.mode?.title ?? "请选择来源")，\(metric.title)，\(display.title)，\(display.detail)")
    }
    @ViewBuilder private var metricSymbol: some View {
        if let fraction = display.energyFraction {
            Gauge(value: fraction) { Image(systemName: display.symbol) }.gaugeStyle(.accessoryCircularCapacity)
        } else { Image(systemName: display.symbol) }
    }
}
private func shortState(_ display: CareMetricPresentation) -> String {
    switch display.title { case "接近个人常态": "常态"; case "身体电量估算": "估算"; default: display.title }
}
@MainActor private func metricConfiguration(_ metric: ComplicationMetric) -> some WidgetConfiguration {
    StaticConfiguration(kind: metric.widgetKind, provider: Provider()) { MetricComplicationView(entry: $0, metric: metric) }
        .configurationDisplayName(metric.configurationTitle)
        .description("图标与状态说明；来自所选报告，缺失及过期明确标注。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
}
struct EnergyWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.energy) } }
struct ReadinessWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.readiness) } }
struct StressWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.stress) } }
struct OverviewComplicationView: View {
    let entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("WRISTLAB · \(entry.originShort)").font(.caption2).widgetAccentable()
                Spacer(minLength: 0)
                if let date = entry.snapshot?.computedAt { Text(date, style: .time).font(.caption2) }
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(ComplicationMetric.allCases) { metric in
                    let display = CareMetricPresentation(snapshot: entry.snapshot, metric: metric, at: entry.date)
                    VStack(alignment: .leading, spacing: 2) {
                        Label(metric.shortTitle, systemImage: display.symbol).font(.caption2)
                        Text(shortState(display)).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                        if let fraction = display.energyFraction { Gauge(value: fraction) { Text("估算") }.gaugeStyle(.linearCapacity).labelsHidden().accessibilityHidden(true) }
                        if let note = display.inputNote { Text(note).font(.caption2) }
                    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
                }
            }
        }.containerBackground(for: .widget) { Color.clear }
            .environment(\.timeZone, TimeZone(identifier: entry.snapshot?.timeZoneID ?? "") ?? .current)
            .widgetURL(ComplicationDestination.overview.url).privacySensitive()
    }
}
struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WristlabOverview", provider: Provider()) { OverviewComplicationView(entry: $0) }
            .configurationDisplayName("Wristlab 状态总览")
            .description("查看身体状态图标，不以分数评价一天。")
            .supportedFamilies([.accessoryRectangular])
    }
}
struct ActivityComplicationView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    private var steps: String {
        entry.daily?.currentSteps(at: entry.date, timeZoneID: TimeZone.current.identifier)
            .map { $0.formatted(.number.precision(.fractionLength(0))) + "步" } ?? "待更新"
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline: Label("手表活动 · \(steps)", systemImage: "figure.walk")
            case .accessoryCorner: Text(steps).widgetLabel { Text("手表活动") }
            case .accessoryCircular:
                VStack { Image(systemName: "figure.walk").widgetAccentable(); Text(steps).font(.caption2).minimumScaleFactor(0.8).lineLimit(1) }
            default:
                VStack(alignment: .leading, spacing: 3) {
                    Label("手表活动", systemImage: "figure.walk").font(.caption2).widgetAccentable()
                    Text(steps).font(.headline).monospacedDigit()
                    if let daily = entry.daily, let minutes = daily.currentRings(at: entry.date, timeZoneID: TimeZone.current.identifier)?.exercise.value {
                        Text("锻炼 \(minutes.formatted(.number.precision(.fractionLength(0)))) 分钟").font(.caption2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.containerBackground(for: .widget) { Color.clear }
            .widgetURL(ComplicationDestination.activity.url).privacySensitive()
            .accessibilityElement(children: .combine)
    }
}
struct ActivityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WristlabActivity", provider: Provider()) { ActivityComplicationView(entry: $0) }
            .configurationDisplayName("Wristlab 今日活动")
            .description("手表可读步数与锻炼分钟；不包含心情，刷新由系统安排。")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
@main
struct WristlabWidgets: WidgetBundle {
    var body: some Widget { EnergyWidget(); ReadinessWidget(); StressWidget(); OverviewWidget(); ActivityWidget() }
}
