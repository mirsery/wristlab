import SwiftUI
import WidgetKit
import WristlabCore

struct Entry: TimelineEntry { let date: Date; let snapshot: DisplaySnapshot? }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = read()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(900))))
    }
    private func read() -> Entry {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mirsery.wristlab.watch")
        let value = base.flatMap { try? Data(contentsOf: $0.appendingPathComponent("watch-receiver.json")) }
            .flatMap { try? JSONDecoder().decode(SnapshotReceiver.self, from: $0) }?.snapshot
        let validated = value.flatMap { (try? $0.validate()) != nil ? $0 : nil }
        return Entry(date: Date(), snapshot: validated?.clearData == true ? nil : validated)
    }
}
struct Complication: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    private var value: Int? { entry.snapshot?.energy.value }
    private var stale: Bool { entry.snapshot.map { $0.isStale(at: entry.date) || $0.energy.isStale(at: entry.date) } ?? false }
    var body: some View {
        Group {
            if family == .accessoryInline {
                Label(stale ? "电量已过期" : value.map { "电量 \($0)" } ?? "等待手机", systemImage: stale ? "clock" : "battery.75percent")
            } else if family == .accessoryCircular {
                Gauge(value: Double(stale ? 0 : value ?? 0), in: 0...100) {
                    Image(systemName: stale ? "clock" : "battery.75percent")
                } currentValueLabel: { Text(stale ? "—" : value.map(String.init) ?? "—") }
                    .gaugeStyle(.accessoryCircular).tint(.mint)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Label(stale ? "Wristlab · 已过期" : "Wristlab · 身体电量", systemImage: "battery.75percent").font(.caption2)
                    Text(value.map { "\($0) / 100" } ?? "等待手机数据").font(.headline)
                    if let date = entry.snapshot?.computedAt { Text(date, style: .time).font(.caption2) }
                }
            }
        }
        .privacySensitive()
        .containerBackground(for: .widget) { Color.black }
        .accessibilityLabel("身体电量 \(value.map(String.init) ?? "暂无数据")\(stale ? "，已过期" : "")")
    }
}
@main
struct WristlabWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WristlabEnergy", provider: Provider()) { Complication(entry: $0) }
            .configurationDisplayName("Wristlab 身体电量")
            .description("显示手机同步的最新估算与更新时间。")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
