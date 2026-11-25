# 手机今日关怀 - 技术设计（Gate 2 已确认）

## Context

用户已确认 Gate 1：原位改造手机今天页，图标与短句优先、数值留详情；不改变模型和权限，仅本地/模拟器验证。

当前 `Apps/iOS/PhoneDashboardView.swift` 的准备度使用 ScoreRing，电量/压力使用 SmallMetricCard，三项都突出整数评分。MetricDetailView 已含数值、贡献及 effectiveAt，但缺少独立报告更新时间。Watch 已有 CareMetricPresentation，但依赖 ComplicationPresentation 和 60 分钟快照 TTL，不能直接用于手机。

权威基线：P-010、metric-insights、`specs/002-scoring.md` 展示分段、MetricEstimate.isStale 和 MetricExplanation。此轮不修改 Watch、健康读取、存储、同步、通知或 iCloud，不更新真机。

## Decisions

### 1. 纯展示模型，不借用 Watch 快照

**方案**：新增 Core 的 PhoneCarePresentation，输入 kind、MetricEstimate、显式 now；输出状态文字、符号、数据说明与可选 energyFraction。复用 MetricExplanation 与现有分段规则，不引入新的分数或持久化数据。准备度用 33/67，压力用 20/60/80 整数边界；压力两端温和文案为“较低/较高”，与手表一致。运动中优先于压力等级，HR-only 就近说明，不推断心情。

**为什么**：同一估算可以有不同展示；直接使用手机指标不会引入 Watch 快照失效时限或等待手机同步文案。

**备选方案及排除原因**：
- 复用 CareMetricPresentation 并构造伪快照：会引入 Watch 的快照校验、清除状态、TTL 与专属话术，排除。
- 将分段与原因直接写进 SwiftUI：边界不易测试且易漂移，排除。

### 2. 三张卡原位替换，连续电量与详情数字分离

新增手机专用 PhoneCareViews 组件承载生产卡片和 NavigationLink；准备度仍占整行，压力/电量仍在原网格，大字体单列。仅替换今天页三指标，不全局更改 SmallMetricCard 或 ScoreRing，避免影响趋势与 Watch。

准备度/压力用 SF Symbols、状态大字及数据质量短句；无数字分数或 /100。电量用自绘连续填充，不新增满/低/恢复等分段文案；有效 0 是有效空填充，缺失则隐藏图形，显示原因图标。图形为装饰语义，入口只朗读名称、状态、数据说明和“查看详情”，数字留在详情。每张卡保留详情入口，不另加关怀长文或第四张卡。

MetricDetailView 保留数值、贡献、原因及模型，并补充 `report.asOf` 报告更新时间，区别于 `metric.effectiveAt` 数据时间；无报告来源/未知时间不伪造。必要时将原详情平移到独立文件以复用生产测试宿主，不重写详情逻辑。

备选：隐藏所有数值包括详情会损失可解释性；新增一个关怀页会加长首页并扩大导航，均排除。

### 3. 时效、演示与布局

PhoneCarePresentation 以 MetricExplanation 的 displayValue 为唯一显示准入；stale > 缺失/校准/失败 > 有效等级。严格遵守 effectiveAt > now 或 now > validUntil，不增加手机 60 分钟 TTL。前台展示由 TimelineView 每 30 秒重算，首页和详情一致；应用恢复前台重新求当前时间。演示固定报告 asOf，不因墙上时钟过期。展示计时器不调用 HealthKit 或 DashboardModel.refresh。

不设置卡片固定高度；状态与原因可换行，辅助字体单列。图标与颜色配文字，不靠颜色判断。今天页滚动标识和现有导航保留。

备选：仅随刷新更新会残留过期等级；复用 Watch 系统后台时间线超出范围，均排除。

## Architecture

DashboardModel.displayed → HealthReport 的三项 MetricEstimate
→ PhoneCarePresentation(kind, estimate, now) → 生产 PhoneCareViews
→ 原 ComplicationMetric 导航 → 生产 MetricDetailView

影响文件（本轮实施范围）：
- `Packages/WristlabCore/Sources/WristlabCore/PhoneCarePresentation.swift` 与对应 Swift Testing。
- `Apps/iOS/PhoneCareViews.swift`、`Apps/iOS/PhoneDashboardView.swift`；必要时平移 MetricDetailView。
- `Tests/Apple/` 的关怀隔离 UI 宿主测试和专用脚本，接入 `scripts/build-apple.sh`。
- `specs/001-product.md`、`specs/002-scoring.md`、验收/验证文档与本 change。

不修改 Physiology、HealthKitReader、DashboardModel 的任务流程、Watch 目标或同步 schema。无新增运行时依赖。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| Watch TTL 导致手机全天准备度提前过期 | 不引用快照；测试报告生成超过 60 分钟但指标有效 |
| 图标掩盖缺数或把 0 当缺数 | 先通过 MetricExplanation；0/nil/stale 分开测试 |
| 压力被理解为心理状态或训练安全保证 | 标明生理压力与实验估算；activity/HR-only 单测；不加建议 |
| UI 正确模型但实际入口不显示 | 隔离宿主复用生产组件和详情，点击三入口；完整 App 模拟器另验 |
| 大字体短句裁切、数字隐藏却被朗读 | 窄屏/最大辅助字体截图、辅助功能树断言；完整 VoiceOver 手势仍待真机 |
| 后续实施偏离或损害稳定真机 | 已确认的本轮长程预授权；小偏差记录，重大偏离重新确认，不安装真机 |

## 设计审查与经验

人工核对 canonical 的 3 项变更均有设计与场景；3 requirements、6 scenarios、6 TC，一一映射，置信度均高。本轮只提供既有模型的展示，不构成健康建议，未引用新的医学或竞品算法，无需外部数据源。

STDD 3.0.5 版本一致。extract-proposal 成功但能力字段解析为空，已从 canonical 确认唯一 phone-today-care；experience list 因上游缺 requests 不可用，不改 vendor/安装依赖。手工读取本地 EXP-20261024-014（实际入口状态可见）和 013（展示不能拥有健康读取生命周期），分别映射 PTC-005/006 与 PTC-004。不声明自动经验检索通过。
