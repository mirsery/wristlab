import SwiftUI
import WristlabCore

struct ActivityWeekSummary: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if let summary = try? ActivityPlanPresentation(state: model.displayedPlanning, now: model.planningNow, timeZoneID: model.planningTimeZone) {
            VStack(alignment: .leading, spacing: 12) {
                Label("本周安排", systemImage: "calendar").font(.headline)
                LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    ForEach(summary.days) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            Text((day.isToday ? "今天 · " : "") + day.date.formatted(reportStyle(.dateTime.month().day().weekday(), model.planningTimeZone)))
                                .font(.caption).foregroundStyle(day.isToday ? wristMint : .secondary)
                            if let entry = day.entry {
                                Text("\(entry.activity) · \(entry.minutes)分钟").font(.subheadline)
                                Text(status(entry.status)).font(.caption).foregroundStyle(.secondary)
                            } else { Text("未安排或未保存记录").font(.caption).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
                    }
                }
                Text("人工状态不代表健康记录达标；未安排不等于休息。").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private func status(_ status: MovementStatus) -> String {
        switch status { case .planned: "计划安排"; case .completed: "手动确认完成"; case .rested: "已选择休息" }
    }
}

struct ActivityPlanManagementView: View {
    @ObservedObject var model: DashboardModel
    @State private var selection = "automatic"
    @State private var sheet: PlanningSheet?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if model.demoEnabled { Text("合成演示 · 不写入真实数据").foregroundStyle(wristMint) }
                Text("查看分段不会切换计划模式；只有采纳或保存才改变安排。").font(.caption).foregroundStyle(.secondary)
                Picker("计划管理", selection: $selection) {
                    Text("自动周计划").tag("automatic")
                    Text("手动模板").tag("manual")
                }.pickerStyle(.menu)
                if selection == "automatic" {
                    AutomaticWeekCard(model: model, configure: { sheet = .automatic })
                        .disabled(model.busy || model.planningBusy)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("手动模板", systemImage: "square.and.pencil").font(.headline)
                        if let plan = model.displayedPlanning.plan {
                            Text("\(plan.activity) · 每次\(plan.minutes)分钟")
                            Text(plan.status == .active ? "模板启用" : "模板暂停或归档").font(.caption)
                        } else { Text("还没有手动模板").foregroundStyle(.secondary) }
                        Text("保存手动模板会切回手动安排；过去和已处理的记录仍保留。").font(.caption).foregroundStyle(.secondary)
                        Button("编辑或建立手动模板") { sheet = .movement }.buttonStyle(.borderedProminent)
                            .disabled(model.busy || model.planningBusy)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
                }
                if let notice = model.planningNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            }.padding(22)
        }
        .background(wristBackground).navigationTitle("管理计划").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { value in
            switch value {
            case .automatic: AutomaticPlanForm(model: model)
            default: MovementPlanForm(model: model)
            }
        }
        .onChange(of: model.demoEnabled) { _, _ in sheet = nil }
    }
}
