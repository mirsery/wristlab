import SwiftUI

struct HealthAccessView: View {
    @State private var message = "真实数据读取独立于上方演示分数。"
    @State private var loading = false
    private let reader = HealthKitReader()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HealthKit 接入验证").font(.headline)
            Text(message).font(.footnote)
            Button("授权并读取最新 HRV") {
                loading = true
                Task { @MainActor in
                    defer { loading = false }
                    do {
                        let result = try await reader.requestAndReadLatestHRV()
                        if let result {
                            message = "HRV（SDNN）\(result.milliseconds.formatted(.number.precision(.fractionLength(1)))) ms · \(result.date.formatted())"
                        } else {
                            message = "暂无可读取的 HRV。可能尚无记录或未允许读取，请在健康 App 检查。"
                        }
                    } catch {
                        message = "读取未完成，请检查设备支持情况及健康设置后重试。"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(loading)
        }
        .padding()
    }
}
