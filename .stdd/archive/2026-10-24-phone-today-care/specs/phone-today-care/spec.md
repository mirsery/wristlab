# Spec: phone-today-care

> Change: 2026-10-24-phone-today-care | Auto-generated Human View

## Requirements

### Requirement: 原位展示可解释的日常状态，不突出评分。

#### Scenario: PTC-001

- **GIVEN** 准备度或压力有当前有效数值，MetricEstimate.value 已按既有规则四舍五入。
- **WHEN** 显示手机今天页指标卡。
- **THEN** SHALL 用图标加短句展示准备度 0–32 较低、33–66 接近个人常态、67–100 较高；压力 0–19 较低、20–59 常态、60–79 偏高、80–100 较高。
- **AND** 压力 activity 模式 SHALL 优先显示运动中，不用压力高低推断心理紧张或心情。
- **AND** HR-only SHALL 就近显示仅心率估算；其他 partial 指标 SHALL 标明部分数据估算。
- **AND** 首页三指标 SHALL 不显示或朗读原始分数、/100 或百分比评分，不新增休息/训练建议。

#### Scenario: PTC-002

- **GIVEN** 身体电量有有效显示整数 0、1、50、100，或无可显示值。
- **WHEN** 生成电量卡片与无障碍标签。
- **THEN** SHALL 只在有有效值时显示按 value/100 连续填充的电量图形及身体电量估算短句，不新增高低等级。
- **AND** 真实 0 SHALL 是有效空填充并标明实验估算；缺失 SHALL 不显示任何有效电量填充，改为原因图标和文字。
- **AND** 图形 SHALL 不通过系统 ProgressView 默认语义朗读百分比，原数值可在详情查看。

### Requirement: 指标原有数据质量与有效期优先于状态图标。

#### Scenario: PTC-003

- **GIVEN** 无报告，或指标校准、缺输入、低覆盖、重校准、读取失败或不支持。
- **WHEN** 展示今天页或打开对应详情。
- **THEN** SHALL 使用 MetricExplanation 的具体原因，不显示正常等级、虚构电量或等待手机同步的 Watch 专属提示。
- **AND** 校准 SHALL 显示实际有效日数及 14 日门槛，不承诺固定自然日后必有分数。
- **AND** 空读取 SHALL 不等同拒绝授权；卡片始终可进入解释详情。

#### Scenario: PTC-004

- **GIVEN** 指标有 effectiveAt/validUntil，且真实时钟或冻结的演示时钟显式传入展示层。
- **WHEN** 时间到达有效期边界、超过有效期或早于有效观测。
- **THEN** SHALL 严格沿用 now > validUntil 或 effectiveAt > now 的过期判定，过期时隐藏等级与电量填充并显示数据已过期。
- **AND** 首页和详情 SHALL 在前台最多 30 秒内更新展示状态；演示时间固定为演示报告 asOf。
- **AND** 有效期内的手机准备度 SHALL 不因报告生成超过 60 分钟而过期；不套用 Watch 快照 TTL。
- **AND** 刷新时间 SHALL 不替代有效观测时间，不因此恢复过期数值；不修改读取或后台任务。

### Requirement: 保留可追溯详情、演示隔离与易读布局。

#### Scenario: PTC-005

- **GIVEN** 今天页的准备度、压力或电量卡，以及真实空报告或合成演示报告。
- **WHEN** 点击卡片并返回。
- **THEN** SHALL 导航到对应生产详情，保留有效数值（包括 0）、贡献依据、数据原因、来源、模型版本与有效观测时间，并分别标出报告 asOf 更新时间。
- **AND** 过期或缺失 SHALL 不显示旧数值或贡献；未知时间/无报告来源 SHALL 不伪造为当前时间或 Apple 健康。
- **AND** 演示 SHALL 始终有合成演示标记，不读取健康、不写真实缓存或同步。
- **AND** 返回 SHALL 保留今天页与其他页签导航行为。

#### Scenario: PTC-006

- **GIVEN** 窄屏及最大辅助字体，包含接近个人常态与长缺失原因。
- **WHEN** 阅读、滚动今天页或用 VoiceOver 访问指标入口。
- **THEN** SHALL 在原三卡位置显示图标、完整状态短句、数据质量说明与详情入口；大字体单列、文字可换行，不固定高度裁切。
- **AND** 图标和颜色 SHALL 不作为唯一信息；每个入口 SHALL 有指标名、状态、原因/数据质量及查看详情语义，无隐藏分数。
- **AND** SHALL 保留日计划和睡眠/活动摘要，不添加第四张关怀卡、额外页签或强制弹层。
