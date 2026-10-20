import SwiftUI
import WristlabCore

struct DashboardView: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wristlab").font(.title2.bold())
            Text(snapshot.source == .demo ? "演示数据 · 非健康评估" : "实验性估算").font(.caption).foregroundStyle(.secondary)
            metric("恢复", value: snapshot.recovery, color: .green)
            metric("身体电量", value: snapshot.energy, color: .cyan)
            metric("压力", value: snapshot.stress, color: .orange)
            Text(snapshot.generatedAt, style: .date).font(.caption2)
            if snapshot.isStale(at: .now) {
                Text("数据已过期").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func metric(_ title: String, value: Int?, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map(String.init) ?? "暂无数据").monospacedDigit().foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }
}
