import Foundation

/// User-facing reasons are shared by the phone, watch, and snapshot displays.
public struct MetricExplanation: Equatable, Sendable {
    public let summary: String
    public let detail: String
    public let displayValue: Int?

    public init(_ metric: MetricEstimate, at now: Date) {
        let energy = metric.mode == "energy"
        if metric.isStale(at: now) {
            displayValue = nil
            summary = "数据已过期"
            detail = "最近的有效观测已超过显示时限。请在手机刷新并查看数据时间；刷新本身不会让旧记录变成新记录。"
            return
        }
        displayValue = metric.value
        switch metric.availability {
        case .calibrating:
            summary = "\(energy ? "夜间基线不足" : "基线校准中") · \(metric.baselineDays)/14天"
            detail = "需要至少14个有效\(energy ? "夜间" : "历史")基线日，目前已有\(metric.baselineDays)个。有效日不要求连续；\(energy ? "需完整主睡眠、睡眠内至少2条有效HRV及对应静息心率。" : "需满足该模式的心率及HRV输入要求。")请持续佩戴手表并核对健康记录；已有记录同步后会重新计算，不保证经过14个自然日就能出分。"
            return
        case .unsupported:
            summary = "暂不支持"
            detail = "当前设备或记录类型不支持该指标。请查看设备及健康数据支持情况。"
            return
        case .failed:
            summary = "读取失败"
            detail = "此次读取或计算未完成。请解锁手机并重试，已有记录不会因此被清除。"
            return
        case .available, .insufficientData: break
        }
        if metric.value != nil {
            summary = metric.quality == .partial ? "部分数据估算" : "基于个人历史"
            detail = metric.reasons.contains("hrOnly") ? "当前仅依据心率和个人基线估算，缺少可配对的近期HRV，因此标为部分估算。" : "根据已选来源和个人历史计算；数据时间、观测覆盖及输入质量会影响结果。"
            return
        }
        let codes = metric.reasons
        if codes.contains("lowCoverage") {
            summary = energy ? "观测覆盖不足80%" : "观测覆盖不足"
            let coverage = metric.coverage.map { "当前约\(Int($0 * 100))%。" } ?? ""
            detail = "\(coverage)\(energy ? "身体电量需要至少80%的观测覆盖。" : "当前有效观测不足。")请持续佩戴并同步记录；未观测时段不会当作休息或补成正常值。"
        } else if codes.contains("observationGap") && codes.contains("recalibrationRequired") {
            summary = "观测中断，需重新校准"
            detail = "连续未观测超过30分钟，电量链已中断。需要后续满足条件的夜间起点或补齐记录后重新计算。"
        } else {
            let code = codes.first ?? "noReadableSamples"
            summary = Self.reasonText(code)
            switch code {
            case "missingPrimarySleep":
                detail = "尚无可用于校准的已完成主睡眠，主睡眠结束至少90分钟后才参与。请在健康App核对对应日期的睡眠记录并同步。"
            case "missingCurrentHRV":
                detail = energy ? "身体电量起点需要主睡眠内至少2条有效HRV记录。请持续佩戴手表并核对健康App中的HRV及睡眠记录。" : "缺少该模式所需的有效HRV记录。请核对健康App中的HRV，并检查Wristlab的读取设置后刷新。"
            case "missingCurrentRHR":
                detail = energy ? "已存在夜间输入，但缺少对应分析日可用的静息心率记录。请核对健康App的记录日期及读取设置后刷新。" : "缺少对应分析日的静息心率；不能借用昨天的值。请核对健康记录及读取设置后刷新。"
            case "missingHR":
                detail = "已选来源没有可用于当前计算的心率记录。请核对健康App中的近期心率、应用读取设置和来源优先级后刷新。"
            case "recalibrationRequired":
                detail = "尚未满足夜间电量起点条件。请持续佩戴并同步完整睡眠、夜间HRV及静息心率；不会默认从100开始。"
            default:
                detail = "请核对健康App中的对应记录、日期及Wristlab读取设置后刷新。没有可读取结果并不能证明读取权限被拒绝。"
            }
        }
    }

    public static func reasonText(_ code: String) -> String {
        ["noReadableSamples": "暂无可读取记录", "missingCurrentHRV": "缺少有效HRV记录",
         "missingCurrentRHR": "缺少对应日静息心率", "missingPrimarySleep": "缺少已完成主睡眠",
         "baselineNotReady": "个人基线校准中", "hrOnly": "仅依据心率估算", "missingHR": "缺少近期心率记录",
         "lowCoverage": "数据覆盖不足", "observationGap": "存在未观测时段", "recalibrationRequired": "等待重新校准",
         "missingMaximumHR": "请先设置最大心率", "missingHistory": "历史记录不足", "sourceConflict": "部分记录存在冲突",
         "awaitingSync": "等待手机同步", "stale": "数据已过期", "aboveConfiguredMaximum": "心率超过已设最大值"][code] ?? "等待更多记录"
    }
}
