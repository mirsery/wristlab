# 000 参考行为与证据边界

规格状态：已定义 v1。核对日期：2026-10-20。运行代码不因本文件变为已实现。

下表仅摘要公开行为。后续002–005中的系数、门槛和完整公式全部是Wristlab实验设计，不是PeakWatch私有算法，也没有效果有效性验证。

## 一手证据

| 来源 | 可以确认 | 未知或限制 |
| --- | --- | --- |
| [REF-01 准备度](https://doc.peakwatch.co/zh_cn/recovery.html) | 比较HRV、RHR与个人历史，提到60天基线及夜间优先/日间回退 | 权重、最少历史和离群规则未知；更新时机描述同时包含晨间与数据变化重算 |
| [REF-02 压力](https://doc.peakwatch.co/zh_cn/hrv-stress.html) | 用心率/HRV历史分布估算压力，HRV默认描述为RMSSD | 无精确拟合式；所述刷新周期不是系统采样保证 |
| [REF-03 电量](https://doc.peakwatch.co/zh_cn/battery.html) | 跨天、充放电、边界附近变化减慢 | 速率未公开；午睡段落仍为iOS18发布前措辞，不能代表当前能力 |
| [REF-04 睡眠](https://doc.peakwatch.co/zh_cn/sleep.html) | 有阶段、债务、规律性、来源优先级 | 综合评分和个人需求公式未公开，旧平台前提需重新核对 |
| [REF-05 体能输出](https://doc.peakwatch.co/zh_cn/exertion.html) | 心率区间时长影响累计负荷，输出非线性，准备度/训练模式影响目标 | 权重、映射和推荐系数未公开 |
| [REF-06 训练负荷](https://doc.peakwatch.co/zh_cn/training-load-ratio.html) | 近期/长期负荷与比例 | 校正和初始化未完整给出，不同文档措辞不完全一致 |
| [REF-07 Apple SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn) | 该类型为SDNN，常用单位ms | 不等于RMSSD；本项目iOS17基线只用SDNN |
| [REF-08 Apple睡眠](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis) | inBed与阶段可能重叠，unspecified无具体阶段 | 不能直接相加；awake不一定覆盖卧床边界 |
| [REF-09 Apple授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) | 按类型授权，不能直接判定读取是否被拒绝 | 请求完成、可读和记录存在不同 |
| [REF-10 Apple同步](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)) | 最新上下文替换旧值，择机发送 | 无固定送达周期和完整事件日志保证 |

## v1取舍

- 复刻准备度/压力/电量的业务关系，精确数值使用[002](002-scoring.md)自定模型。
- 睡眠实现[004](004-sleep.md)可核对的汇总、债务和规律性；暂不编造综合睡眠分。
- 运动按[005](005-activity.md)定义HRR负荷、输出和参考目标；不声称复制原版TRIMP、校正系数或风险阈值。
- AI、饮食、课程、身体年龄等不属于当前范围，见[001](001-product.md)。

## 验收标准

- REF-A01：外部行为可回溯来源，推断和自定公式明确归属。
- REF-A02：不声称与原版分数一致；SDNN不标为RMSSD。
- REF-A03：公开文档过时/冲突/未知时，以仓库显式约定实现，保留差异。
