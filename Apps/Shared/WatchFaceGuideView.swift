import SwiftUI
import WristlabCore

/// These illustrations never read or write the real Watch snapshot cache.
struct WatchFaceGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("抬腕，看清此刻", systemImage: "clock").font(.headline).foregroundStyle(wristMint)
                Text("把身体电量、训练准备度和生理压力放到你喜欢的表盘上。").font(.footnote).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Label("合成演示预览", systemImage: "sparkles").font(.caption).foregroundStyle(wristMint)
                    HStack(spacing: 4) {
                        sample(.energy, value: 76, color: .cyan)
                        sample(.readiness, value: 89, color: wristMint)
                        sample(.stress, value: 39, color: .orange)
                    }
                    Text("仅示意布局，不代表你的健康状态。").font(.caption2).foregroundStyle(.secondary)
                }.padding(12).background(wristCard, in: RoundedRectangle(cornerRadius: 18))
                instructions("在 Apple Watch 上", steps: ["长按当前表盘，轻点“编辑”。", "滑动到“复杂功能”，选择一个位置。", "选择 Wristlab，再选择电量、准备度、压力或状态总览。"])
                instructions("在 iPhone 上", steps: ["打开系统 Watch App，进入“我的表盘”。", "选择表盘，在“复杂功能”中选择 Wristlab 组件。", "保存后，确认手表正在使用这款表盘。"])
                VStack(alignment: .leading, spacing: 8) {
                    Text("选哪一种？").font(.headline)
                    Text("单项指标支持圆形、矩形、行内和角落位置；状态总览需要矩形位置。可选样式取决于表盘。").font(.footnote)
                    Text("轻点组件可打开对应报告。数据来自手机最近一次同步；过期显示“—”，刷新时机由系统决定。").font(.footnote).foregroundStyle(.secondary)
                    Text("找不到 Wristlab？先确认手表端应用已安装并打开过，再重新进入表盘编辑器。").font(.footnote).foregroundStyle(.secondary)
                }
            }.padding()
        }
        .background(wristBackground)
        .navigationTitle("表盘组件")
    }
    private func sample(_ metric: ComplicationMetric, value: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: metric.symbol).font(.caption).foregroundStyle(color)
            Text("\(value)").font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(metric.shortTitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
    private func instructions(_ title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(wristMint)
                    Text(step).font(.footnote)
                }
            }
        }
    }
}
