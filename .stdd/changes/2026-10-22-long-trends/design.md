# 长期趋势、个人基线区间与近7日回顾 - 技术设计（Gate 1/2已确认，实施中）

## Context

HealthEngine为D-60…D共61个分析日构建逐日basis（主睡眠、夜间HRV配对、日间回退、清醒/睡眠桶），但报告history只取最后7日，且只含准备度、睡眠时长与负荷。准备度用前60日同睡眠来源的夜间成对日计算ln(HRV)与静息心率的中位数和MAD尺度（下限0.1与3），至少14个有效日。上一轮已有TrendSeries（7日、类别轴、分析时区）与“接近个人基线”=|z|<0.5的展示约定。

## Decisions

### 1. history扩到35日并带逐日夜间输入

**方案**：history = basis.suffix(35)；DayOverview新增可选nightHRV（主睡眠内有效HRV≥2条的中位数，与夜间配对同口径）与restingHeartRate（当日静息心率，与准备度同一取值顺序）。

**为什么**：周回顾需要本周7日+前28日；30日趋势在其内。数据已在basis中，无需新读取。

**备选**：单独新增长历史字段——与history语义重复，拒绝。90日——超出61日basis，需要扩大读取窗口，本轮不做。

### 2. personalRanges（个人基线区间）与今天准备度同一基线

**方案**：Physiology新增`personalRanges(history:)`，与`readiness`共用有效日过滤、distribution与尺度下限（`readinessBaseline`），区间宽度用共享常量`Physiology.nearBaselineZ`（0.5）：HRV exp(c±0.5s)、静息心率c±0.5s，并给有效日数。引擎只在今天准备度为夜间模式时，用与`readiness(todayRow)`完全相同的history（`readinessHistory(todayRow, nightMode: true)`：前60日、今天主睡眠来源）计算；日间回退或不足14日为nil。

**为什么**：复审发现原实现在今天无睡眠时按nil来源混入所有来源，且日间回退时准备度根本不用夜间基线；限定夜间模式后，区间、贡献分解的“接近个人基线”与准备度数值是同一把尺子（测试断言days与baselineDays、中心与baselineHRV/RHR相等）。

**备选**：今天无睡眠时取最近一次主睡眠来源——与今天准备度不是同一基线，拒绝；人群标准值——违背个人基线原则。命名不用“个人常态范围”，避免与准备度33–66分段“接近个人常态”混淆。

### 3. 趋势卡片

**方案**：TrendSeries增加`length`（7或30）与指标nightHRV、restingHeartRate。卡片顶部分段选择7/30日，指标用Menu选择五项。准备度/睡眠/负荷为柱形；HRV/静息心率为折线+点（缺失断开），有personalRanges时画范围带并在页脚注明“个人常态范围：本人前60日夜间基线”。30日横轴每5日标一次日期。

### 4. WeeklyReview（近7日回顾）

**方案**：Core新增WeeklyReview(history:endingAt:timeZoneID:)，对准备度、睡眠（小时）、夜间HRV、静息心率计算近7日（D-6…D）与此前28日（D-34…D-7）均值；近7日≥3个、此前28日≥10个有效日才给均值，两者都有才给差值；`differenceText`按显示精度先取整再相减，零不带符号。负荷不参与（含部分观测日）。界面称“近7日/此前28日”，避免被读成自然周。

**为什么**：参考WHOOP/Oura周报，但只陈述差值，不推断原因。

## Architecture

```text
HealthEngine.evaluate
  basis(61日) ─ history(35日, +nightHRV/restingHeartRate)
            └─ 今日夜间history → Physiology.personalRanges → report.personalRanges?
InsightPresentation: TrendSeries(length 7|30, 5指标) / WeeklyReview
PhoneDashboardView: 趋势卡片(7/30 + 指标Menu + 范围带) / 周回顾卡片
```

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 扩展history误改评分 | 只改输出列表长度与字段；LONG-001对照数值与校验和 |
| 旧缓存缺新字段 | 全部Optional；LONG-004解码测试 |
| 范围带被当作医学正常值 | 命名“个人常态范围”并注明来源与不是人群标准 |
| 今日数据未完成拉低本周均值 | 周回顾标明“含今天”，有效天门槛避免小样本 |
