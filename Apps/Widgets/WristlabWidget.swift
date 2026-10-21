import SwiftUI
import WidgetKit
import WristlabCore

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: DisplaySnapshot?
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date(), snapshot = read()
        let entries = ComplicationTimeline.dates(snapshot: snapshot, now: now).map { Entry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(900))))
    }
    private func read() -> DisplaySnapshot? {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mirsery.wristlab.watch")
        let data = folder.flatMap { try? Data(contentsOf: $0.appendingPathComponent("watch-receiver.json")) }
        return ComplicationCache.snapshot(from: data)
    }
}

private extension ComplicationMetric {
    var color: Color {
        switch self { case .energy: .cyan; case .readiness: .mint; case .stress: .orange }
    }
    var destination: ComplicationDestination {
        switch self { case .energy: .energy; case .readiness: .readiness; case .stress: .stress }
    }
}
struct MetricComplicationView: View {
    let entry: Entry
    let metric: ComplicationMetric
    @Environment(\.widgetFamily) private var family
    private var display: ComplicationPresentation { ComplicationPresentation(snapshot: entry.snapshot, metric: metric, at: entry.date) }
    private var symbol: String { display.state == .stale ? "clock" : metric.symbol }
    private var score: String { display.value.map(String.init) ?? "—" }
    private var accessible: Text {
        let label = Text("\(metric.title)，\(display.value.map { "\($0)分" } ?? "暂无数值")，\(display.statusText)")
        if let date = display.updatedAt { return label + Text("，更新于") + Text(date, style: .time) }
        return label
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(display.value.map { "\(metric.shortTitle) \($0)\(display.state == .partial ? " · 估算" : "")" } ?? "\(metric.shortTitle) · \(display.statusText)", systemImage: symbol)
            case .accessoryCircular:
                if let value = display.value {
                    Gauge(value: Double(value), in: 0...100) {
                        Image(systemName: metric.symbol)
                    } currentValueLabel: { Text(score).monospacedDigit() }
                        .gaugeStyle(.accessoryCircular).tint(metric.color)
                } else {
                    VStack(spacing: 1) {
                        Image(systemName: symbol).font(.caption2)
                        Text("—").font(.headline)
                        Text(display.statusText).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            case .accessoryCorner:
                Text(score).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                    .widgetLabel { Text("\(metric.shortTitle) · \(display.statusText)") }
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Label(metric.title, systemImage: symbol).font(.caption2).widgetAccentable()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(score).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                        Text(display.statusText).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    if let date = display.updatedAt { Text(date, style: .time).font(.system(size: 9)).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .environment(\.timeZone, TimeZone(identifier: entry.snapshot?.timeZoneID ?? "") ?? .current)
        .widgetURL(metric.destination.url)
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessible)
    }
}
@MainActor private func metricConfiguration(_ metric: ComplicationMetric) -> some WidgetConfiguration {
        StaticConfiguration(kind: metric.widgetKind, provider: Provider()) { MetricComplicationView(entry: $0, metric: metric) }
            .configurationDisplayName("Wristlab \(metric.title)")
            .description("显示最近同步的估算；缺失或过期会明确标注。")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
}
struct EnergyWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.energy) } }
struct ReadinessWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.readiness) } }
struct StressWidget: Widget { var body: some WidgetConfiguration { metricConfiguration(.stress) } }
struct OverviewComplicationView: View {
    let entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("WRISTLAB").font(.system(size: 8, weight: .bold)).tracking(1).widgetAccentable()
                Spacer(minLength: 2)
                if let date = entry.snapshot?.computedAt { Text(date, style: .time).font(.system(size: 8)).foregroundStyle(.secondary) }
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(ComplicationMetric.allCases) { metric in
                    let display = ComplicationPresentation(snapshot: entry.snapshot, metric: metric, at: entry.date)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(metric.shortTitle).font(.system(size: 9)).lineLimit(1)
                        Text(display.value.map(String.init) ?? "—").font(.system(.headline, design: .rounded)).monospacedDigit()
                        if display.state != .current { Text(display.statusText).font(.system(size: 7)).lineLimit(1).minimumScaleFactor(0.7) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .environment(\.timeZone, TimeZone(identifier: entry.snapshot?.timeZoneID ?? "") ?? .current)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(ComplicationDestination.overview.url)
        .privacySensitive()
        .accessibilityElement(children: .combine)
    }
}
struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WristlabOverview", provider: Provider()) { OverviewComplicationView(entry: $0) }
            .configurationDisplayName("Wristlab 状态总览")
            .description("同时查看电量、准备度与压力；点击打开手表报告。")
            .supportedFamilies([.accessoryRectangular])
    }
}
@main
struct WristlabWidgets: WidgetBundle {
    var body: some Widget {
        EnergyWidget()
        ReadinessWidget()
        StressWidget()
        OverviewWidget()
    }
}
