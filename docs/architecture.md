# 架构

## 当前数据流

```text
HealthKitReader / DemoData
  → RecordNormalizer（校验、去重、固定来源）
  → SleepCalculator（区间、episode、报告）
  → HealthEngine（个人基线、准备度、分时压力、活动）
  → EnergyCalculator（种子、分钟积分、缺口与重放）
  → HealthRepository（记录、anchor、报告原子提交）
  → 手机报告/Charts/解释
  → DisplaySnapshot → WatchBridge → SnapshotReceiver
                                  → Watch / App Group / WidgetKit
```

## 模块边界

- WristlabCore只依赖Foundation，模型均可Codable/Sendable。日期、时区、配置和asOf显式输入；数据不足为状态，不给默认正常分。
- iOS适配器在系统回调边界把HKSample转为规范值。HealthKit读取权限请求与可读记录分开处理，观察完成回调在刷新后执行。
- HealthRepository为actor，串行计算并原子写文件；失败不推进anchor、旧revision不能覆盖新任务。当前以确定性全量重放优先保证一致性，最多保留150日规范记录，不依赖不完整的增量电量检查点。
- iPhone是评分权威。Watch和Widget只展示最小快照，校验schema、producer、epoch/sequence与数值。App Group缓存是Watch与组件的共同来源。
- 演示通过相同业务引擎处理合成记录，界面有明确标识；真实同步拒收demo来源。

## ADR-001：原生双端，共享领域包

采用SwiftUI、HealthKit、WatchConnectivity与WidgetKit，直接覆盖手表系统能力。领域计算放入纯Swift包，可在不启动设备和UI的情况下验证。Apple API留在适配层。

## ADR-002：工程生成与本地签名

project.yml是工程来源，XcodeGen生成文件不提交。CI关闭签名编译模拟器；个人team、证书与provisioning不进公开仓库。Watch和Widget的App Group需在真机签名阶段保持一致。

## ADR-003：明确的实验模型与数据状态

原版精确算法未公开，采用spec中版本化的原创实验映射。保留来源、时间、模式、基线天数、覆盖和原因；有公式不代表有效性验证。缺口不静默补值，真实模式不回退演示。

## 测试与性能

使用公共业务API、JSON数值金例和合成历史验证。当前几十日历史的端到端计算在本地测试中可执行；实际设备性能仍需观测。优化应保持全量/增量与乱序结果一致，不能以省时为由改变缺失策略。

[业务依赖](../specs/007-implementation-plan.md) · [数据与协议](../specs/003-health-and-sync.md) · [验证状态](validation.md)
