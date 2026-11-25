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

Watch独立分支：`SharedHealth/HealthKitReader → Watch私有HealthRepository → 同一HealthEngine → local快照`；手机快照仍经原SnapshotReceiver保存在独立phone缓存。`WatchReportModel → WatchDisplayEnvelope → Watch UI / Widget`以单一原子展示包提交所选来源，切换不跨producer混比revision或拼接指标。停止标记先持久化，清理失败重启保持停止；普通展示写失败则保留旧展示并可重试。协议与选择/分页逻辑在Core，Apple API留在适配层，协调器通过Swift Package的WatchSupport目标做可控测试。

可选界面偏好支路与健康仓库隔离：`TrendsNavigationState → InterfacePreferences → PreferenceSyncCoordinator → iOS CloudKit私有库`。载荷仅四项选择和版本/删除元数据；账户环境分区、epoch拒绝晚回调、服务端版本冲突需选择，删除标记阻旧副本自动复活。独立缓存排除系统备份，演示不发送；健康/体重/计划及健康配置不进此支路。真实签名/两设备验证见icloud-data-center报告，不能把实现当可用。

- WristlabCore只依赖Foundation，模型均可Codable/Sendable。日期、时区、配置和asOf显式输入；数据不足为状态，不给默认正常分。
- iOS适配器在系统回调边界把HKSample转为规范值。HealthKit读取权限请求与可读记录分开处理，观察完成回调在刷新后执行。应用启动委托恢复已启用的观察，不依赖前台视图task；锁屏暂不可读时保留文件并在前台启动重试。
- HealthRepository为actor，串行计算并原子写文件；失败不推进anchor、旧revision不能覆盖新任务。当前以确定性全量重放优先保证一致性，最多保留150日规范记录，不依赖不完整的增量电量检查点。
- 手机模式以iPhone为生产者，Watch独立模式以自身仓库为生产者，两者同算法但不保证不同输入同分。App与表盘共同读取已选来源展示包，缺失/损坏不偷偷回退其它来源。手机原接收分区仍校验schema、producer、epoch/sequence与数值；iPhone小组件仍读手机自己的最近一次真实快照，不受手表本地模式影响。
- 演示通过相同业务引擎处理合成记录，界面有明确标识；真实同步拒收demo来源。

## ADR-001：原生双端，共享领域包

采用SwiftUI、HealthKit、WatchConnectivity与WidgetKit，直接覆盖手表系统能力。领域计算放入纯Swift包，可在不启动设备和UI的情况下验证。Apple API留在适配层。

## ADR-002：工程生成与本地签名

project.yml是工程来源，XcodeGen生成文件不提交。CI关闭签名编译模拟器；个人team、证书与provisioning不进公开仓库。Watch与表盘组件、iPhone与iPhone小组件各自的App Group需在真机签名阶段保持一致。

## ADR-003：明确的实验模型与数据状态

原版精确算法未公开，采用spec中版本化的原创实验映射。保留来源、时间、模式、基线天数、覆盖和原因；有公式不代表有效性验证。缺口不静默补值，真实模式不回退演示。

## 测试与性能

使用公共业务API、JSON数值金例和合成历史验证。当前几十日历史的端到端计算在本地测试中可执行；实际设备性能仍需观测。优化应保持全量/增量与乱序结果一致，不能以省时为由改变缺失策略。

[业务依赖](../specs/007-implementation-plan.md) · [数据与协议](../specs/003-health-and-sync.md) · [验证状态](validation.md)
