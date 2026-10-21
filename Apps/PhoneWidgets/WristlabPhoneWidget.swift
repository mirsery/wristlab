import SwiftUI
import WidgetKit
import WristlabCore

struct PhoneEntry: TimelineEntry {
    let date: Date
    let snapshot: DisplaySnapshot?
}
struct PhoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhoneEntry { PhoneEntry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (PhoneEntry) -> Void) {
        completion(PhoneEntry(date: Date(), snapshot: read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PhoneEntry>) -> Void) {
        let now = Date(), snapshot = read()
        let entries = PhoneWidgetSummary(snapshot: snapshot, at: now).dates(now: now).map { PhoneEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800))))
    }
    private func read() -> DisplaySnapshot? {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PhoneWidgetCache.appGroup)
        return PhoneWidgetCache.snapshot(from: folder.flatMap { try? Data(contentsOf: $0.appendingPathComponent(PhoneWidgetCache.fileName)) })
    }
}

private extension ComplicationMetric {
    var tint: Color { switch self { case .readiness: .mint; case .energy: .cyan; case .stress: .orange } }
}
struct PhoneSummaryView: View {
    let entry: PhoneEntry
    @Environment(\.widgetFamily) private var family
    private var summary: PhoneWidgetSummary { PhoneWidgetSummary(snapshot: entry.snapshot, at: entry.date) }
    private func score(_ metric: ComplicationPresentation) -> String { metric.value.map(String.init) ?? "—" }
    private func status(_ metric: ComplicationPresentation) -> String { summary.statusText(metric) }
    /// Short line for tight families: the value, marked when partial, or the reason.
    private func compact(_ metric: ComplicationPresentation) -> String {
        "\(metric.metric.shortTitle) " + (metric.value.map { "\($0)\(metric.state == .partial ? " · 估算" : "")" } ?? "— · \(status(metric))")
    }
    private var spoken: String {
        summary.metrics.map { "\($0.metric.title)\($0.value.map { "\($0)分" } ?? "暂无数值")，\(status($0))" }.joined(separator: "；")
    }
    var body: some View {
        content
            // The background is always dark, so secondary text must resolve for a dark scheme.
            .environment(\.colorScheme, .dark)
            .environment(\.timeZone, TimeZone(identifier: entry.snapshot?.timeZoneID ?? "") ?? .current)
            .containerBackground(for: .widget) { Color(red: 0.035, green: 0.055, blue: 0.075) }
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken + (summary.updatedAt.map { "；更新于\($0.formatted(date: .omitted, time: .shortened))" } ?? ""))
    }
    @ViewBuilder private var content: some View {
        let readiness = summary.metrics[0]
        switch family {
        case .accessoryInline:
            Label(summary.metrics.contains { $0.value != nil } ? summary.metrics.map { "\($0.metric.shortTitle) \(score($0))" }.joined(separator: " · ")
                  : "Wristlab · \(status(readiness))", systemImage: "waveform.path")
        case .accessoryCircular:
            if let value = readiness.value {
                Gauge(value: Double(value), in: 0...100) { Image(systemName: "leaf") } currentValueLabel: { Text("\(value)").monospacedDigit() }
                    .gaugeStyle(.accessoryCircular)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: readiness.state == .stale ? "clock" : "leaf").font(.caption2)
                    Text("—").font(.headline)
                    Text(status(readiness)).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("WRISTLAB").font(.system(size: 9, weight: .bold)).widgetAccentable()
                ForEach(summary.metrics, id: \.metric) { metric in
                    Text(compact(metric)).font(.caption2).lineLimit(1)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ForEach(summary.metrics, id: \.metric) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(metric.metric.shortTitle, systemImage: metric.metric.symbol).font(.caption).foregroundStyle(metric.metric.tint)
                        Text(score(metric)).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
                        Text(status(metric)).font(.caption2).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.8)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            updated
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("准备度", systemImage: "leaf").font(.caption).foregroundStyle(.mint)
                Text(score(readiness)).font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text(status(readiness)).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                HStack {
                    Text("电量 \(score(summary.metrics[1]))").foregroundStyle(.cyan)
                    Text("压力 \(score(summary.metrics[2]))").foregroundStyle(.orange)
                }.font(.caption2).monospacedDigit()
                updated
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private var updated: some View {
        if let date = summary.updatedAt {
            Text(date, style: .time).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

struct WristlabPhoneSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        // WidgetKit rejects interpolated names at registration; keep these literal.
        StaticConfiguration(kind: "WristlabPhoneSummary", provider: PhoneProvider()) { PhoneSummaryView(entry: $0) }
            .configurationDisplayName("Wristlab 状态")
            .description("显示手机最近一次计算的准备度、电量与压力；缺失或过期会明确标注。")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
@main
struct WristlabPhoneWidgets: WidgetBundle {
    var body: some Widget { WristlabPhoneSummaryWidget() }
}
