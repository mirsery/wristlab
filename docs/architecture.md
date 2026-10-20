# 架构

## 决策 ADR-001：原生双端，共享领域模型

状态：采用。原因：自用项目需要 HealthKit、watchOS 与系统表盘能力，原生框架可直接覆盖这些能力。

- `Packages/WristlabCore`：Foundation 模型、数据质量、算法与序列化。纯 Swift；测试需要具备 Swift Testing 支持的工具链，当前使用 CI 的完整 Xcode。
- `Apps/iOS`：SwiftUI 应用与 HealthKit adapter。当前仅有 HRV 读取验证，尚不生成评分。
- `Apps/watchOS`：SwiftUI 手表应用，当前独立展示合成快照。
- `Apps/Shared`：两端共享的轻量展示视图。
- 后续 WatchConnectivity 与 WidgetKit adapter 随对应 spec 验收实现，不预先引入空服务。

数据流目标：HealthKit → 标准化与去重 → 数据质量/个体基线 → 版本化估算 → 本地快照 → UI / WatchConnectivity / WidgetKit。
当前数据流：合成快照 → 双端 UI；iPhone 用户主动授权 → 最近 7 天最新 SDNN 样本 → 独立文本。

## 决策 ADR-002：工程生成

`project.yml` 为工程唯一来源，由 XcodeGen 生成 `Wristlab.xcodeproj`；不提交生成文件。签名 team 在本地设置。CI 编译模拟器，不使用签名密钥。

## 决策 ADR-003：评分后置

骨架不生成伪装为健康测量的分数。实验模型经 spec、合成测试、真机数据覆盖检查后逐项上线；模型版本与更新时间进入最终持久化快照。当前快照仅供搭建序列化边界，不代表最终同步协议。

业务规则依赖和正式报告契约分别见 [007](../specs/007-implementation-plan.md) 与 [003](../specs/003-health-and-sync.md)。本轮只定义目标契约，未迁移旧演示容器。
