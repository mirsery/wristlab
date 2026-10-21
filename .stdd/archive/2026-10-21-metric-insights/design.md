# 讲清楚已有估算 - 技术设计（Gate 1/2已确认，实施中）

## Context

iPhone首页只展示分数。HealthEngine已经产出stressTimeline（当天5分钟压力桶）、SleepReport的segments/efficiency/latency/awake/naps、7日DayOverview的睡眠与负荷，但界面未使用；详情页“计算依据”直接列出contributions原始ms/bpm，看不出与个人基线的关系。准备度和压力的产品分段已在[002](../../../specs/002-scoring.md)定义（准备度0–32/33–66/67–100，压力0–19/20–59/60–79/80–100），首页仍用“给自己一点休息”等带建议意味的自拟文案。

约束：评分公式、门槛、模型版本、HealthKit读取类型、Watch同步schema与Watch端不变；12份数值金例不变。AGENTS.md要求平台无关逻辑放在WristlabCore、View只消费模型。经验EXP-20261021-001提示不同界面映射不一致会误导，本次新增展示统一由Core模型产出，过期与演示状态沿用MetricExplanation。

## Decisions

### 1. 新增纯展示模型文件 InsightPresentation.swift

**方案**：WristlabCore新增MetricContributions、MetricTier、DayTimeline、SleepBreakdown、TrendSeries五个纯Foundation模型，输入HealthReport/MetricEstimate/SleepReport，输出可直接渲染的行、区段、分段序列。PhoneDashboardView和新SleepDetailView只做布局。

**为什么**：边界规则要求View不做计算；纯模型可用合成数据单测缺失、断线和边界。

**备选方案及排除原因**：
- 在View内计算：无法单测，且与Watch或后续小组件复用时会产生EXP-001那类映射不一致。
- 扩展MetricExplanation：它专注缺失原因，混入图表和贡献逻辑会使其失去单一职责。

### 2. 贡献效果按已截断z值判定，阈值±0.5

**方案**：准备度：zHRV>0表示HRV高于基线、推高准备度；zRHR>0表示静息心率低于基线、推高准备度。压力：zHR>0表示心率高于基线、推高压力；zHRV>0表示HRV低于基线、推高压力。|z|<0.5显示“接近个人基线”，z≥0.5显示“推高…”，z≤−0.5显示“拉低准备度/降低压力”。数值行显示当前值、个人基线和差值（当前−基线，按单位取整）。z值本身不显示。

**为什么**：z已经是模型内按个人离散度标准化、截断到[−3,3]的贡献，方向与分数公式一致；0.5是纯展示分段，不改变公式。用“推高/拉低”描述对指标的作用，不使用“好/坏”或训练建议。

**备选方案及排除原因**：
- 按原始差值百分比判定：每人离散度不同，同样5%对不同人意义不同，且与公式方向可能不一致。
- 显示z值：内部量，对用户无意义。

### 3. 压力HRV行只显示方向

**方案**：压力有HRV输入（quality complete且reasons不含hrOnly，mode非activity）时显示HRV行，仅有方向和效果，不显示数值；HR-only和运动桶不显示HRV行。

**为什么**：Physiology.stress的contributions只有zHRV，没有原始HRV和基线；HR-only时zHRV固定为0，不能据此显示“接近基线”。本轮不改Physiology的输出。

**备选方案及排除原因**：
- 在stress contributions新增hrv/baselineHRV键：属于评分模块输出变化，本轮不做。

> Build复审更正（Gate 3待用户复核）：Gate 2展示的原理由“补原始键会改变Watch快照载荷”与代码不符。DisplaySnapshot.init会清空所有contributions（StorageAndSync.swift），Watch收不到贡献项；补键只会改变iPhone本地报告缓存内容。结论“只显示方向”未变，但依据改为“本轮不改Physiology输出”。另：HR-only判定改为reasons含hrOnly或mode为activity；跨睡眠边界的partial+sourceConflict桶仍用了HRV，照常列行。

### 4. EnergyReport新增可选的区间字段

**方案**：EnergyReport新增`asleepIntervals: [DateInterval]?`和`workoutIntervals: [DateInterval]?`，由HealthEngine写入电量重放实际使用的asleep与workout区间，裁剪到分析日起点至asOf。DayTimeline据此在电量曲线下绘制睡眠（含小睡）和运动区段。

**为什么**：区段正是驱动电量充放的输入，标注与曲线一致；当日午后小睡属于下一睡眠报告窗口，只用SleepReport会漏标。

**备选方案及排除原因**：
- 由压力桶mode=activity推导运动：依赖心率存在且只有5分钟精度；电量重放对运动的扣电与心率无关，会出现曲线下降而无标注。
- 只用SleepReport.primary/naps：漏掉下一窗口的当日小睡。

兼容性：字段为Optional，旧仓库状态解码为nil，界面不标区段直到下次重算；DisplaySnapshot不含EnergyReport的这两个字段，同步schema与schemaVersion不变；数值金例只测函数级公式，不受影响。

### 5. 一天的节奏改为两张共享时间轴的图

**方案**：上图为电量折线，背景叠加睡眠（靛蓝）与运动（黄）区段；下图为压力折线（只连接相邻且有值的桶），运动桶点用空心标记并在图例注明“运动中”。两图x轴均为分析日00:00至24:00，数据只到asOf。图例文字标注颜色含义，不只靠颜色。

**为什么**：电量与压力都是0–100但含义相反，叠在一张图上易误读；分开后共享时间轴仍可对照。

**备选方案及排除原因**：
- 两条线叠在一张图：颜色是唯一区分，读数困难。

### 6. 睡眠详情页与7日趋势切换

**方案**：首页睡眠卡改为NavigationLink进入SleepDetailView：主睡眠阶段时间轴（泳道顺序为清醒、REM、核心、深睡；未细分与未知各占一行），效率、入睡用时、已记录清醒时长与次数、小睡列表，空值显示“—”并说明原因。7日卡片顶部加分段Picker（准备度/睡眠/负荷），固定以report.day为终点的7个日历日，缺失日不画柱，页脚显示“有效N/7天 · 均值X”（N=0时无均值）。

**为什么**：数据全部已有，按004空值规则处理即可；固定7日轴让缺口可见。

**备选方案及排除原因**：
- 睡眠详情作为首页展开区：首页已长，独立页面更符合现有指标详情的交互。

### 7. 分段短句沿用002，首页去掉建议文案

**方案**：MetricTier按002分段返回“较低/接近个人常态/较高”（准备度）与“低/常态/偏高/高”（压力），电量返回nil。首页准备度主标题显示“准备度较高”等，压力卡在状态行前显示分段。无数值不显示分段，真实0显示最低分段。

**为什么**：分段已是规格事实，复用避免新造口径；去掉祈使句避免训练处方意味（002 A-006）。

## Architecture

```text
HealthEngine.evaluate
  ├─ energy.points / energy.asleepIntervals / energy.workoutIntervals (新增可选)
  ├─ stressTimeline, sleep, history, readiness, stress
  ▼
InsightPresentation (WristlabCore, 纯函数)
  ├─ MetricContributions(metric, kind, at:) → [ContributionRow]
  ├─ MetricTier.label(kind, value)          → String?
  ├─ DayTimeline(report)                     → energy段 / stress段 / spans
  ├─ SleepBreakdown(sleep)                   → 泳道段 / 阶段时长与占比 / 指标
  └─ TrendSeries(history, metric, endingAt)  → 7点 / 有效天数 / 均值
  ▼
Apps/iOS：PhoneDashboardView（首页卡片、两张图、趋势Picker）
          MetricDetailView（贡献行替代原始键）
          SleepDetailView（新）
```

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| “推高/拉低”被理解为医疗或训练判断 | 文案写入001规格并经Gate 2确认；详情保留实验估算声明；不出现建议性祈使句 |
| 稀疏压力桶被连成连续曲线 | 只连接首尾相接且有值的桶；单测覆盖空隙与nil |
| 无阶段或无数据显示成0 | SleepBreakdown按004返回nil；TrendSeries缺失日为nil；单测覆盖 |
| 旧缓存缺少新区间字段 | Optional解码为nil，不标区段且不崩溃；单测覆盖旧JSON解码 |
| 过期指标仍展示贡献 | 贡献行以MetricExplanation.displayValue非nil为前提，过期时为空 |
| 演示数据在新页面未标记 | 睡眠详情页与首页同样显示合成演示标签；模拟器截图检查 |
