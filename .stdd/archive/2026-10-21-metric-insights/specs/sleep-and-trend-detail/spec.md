# Spec: sleep-and-trend-detail

> Change: 2026-10-21-metric-insights | Auto-generated Human View

## Requirements

### Requirement: 阶段时间轴

#### Scenario: SC-SLEEPUI-001

- **GIVEN** 主睡眠含清醒、REM、核心、深睡、未细分与unknown段，另有inBed记录
- **WHEN** 生成SleepBreakdown泳道
- **THEN** SHALL 按清醒、REM、核心、深睡、未细分、未知顺序输出泳道段，不含inBed
- **AND** 泳道取自完整睡眠分段与主睡眠区间的交集，主睡眠内的清醒与未知段同样显示
- **AND** 不合并不同阶段

### Requirement: 空值不当0

#### Scenario: SC-SLEEPUI-002

- **GIVEN** 睡眠有时长但无任何具体阶段，效率与入睡潜伏为nil
- **WHEN** 生成阶段时长、占比与指标
- **THEN** SHALL 具体阶段时长与占比为nil，未细分可显示；效率与入睡用时为nil
- **AND** 有具体阶段时未出现的具体阶段为0，四项占比和为100%

#### Scenario: SC-SLEEPUI-003

- **GIVEN** 没有主睡眠但有小睡，或完全无睡眠记录
- **WHEN** 生成SleepBreakdown
- **THEN** SHALL 不输出泳道；小睡列表照常输出；无记录时总时长为nil
- **AND** 无任何睡眠分段时已记录清醒时长与次数为nil，界面显示“—”

### Requirement: 睡眠指标

#### Scenario: SC-SLEEPUI-004

- **GIVEN** 报告有效率、入睡潜伏、已记录清醒时长与次数及两段小睡
- **WHEN** 打开睡眠详情页
- **THEN** SHALL 显示效率百分比、入睡用时、“已记录清醒”时长与次数、按时间排序的小睡起止与时长；演示模式显示合成标签

### Requirement: 7日趋势切换

#### Scenario: SC-TREND-001

- **GIVEN** history缺少某日条目且某日值为nil，分别选择准备度、睡眠、负荷
- **WHEN** 生成TrendSeries
- **THEN** SHALL 输出以报告日为终点的连续7个日历日，缺失日值为nil；有效天数为非nil个数
- **AND** 睡眠值以小时表示
- **AND** 均值只按有效天计算，有效天数为0时均值为nil
- **AND** 日期按固定分析时区的日历日生成，夏令时切换周仍为7个连续日

#### Scenario: SC-TREND-002

- **GIVEN** 首页7日卡片
- **WHEN** 切换准备度、睡眠、负荷
- **THEN** SHALL 只为非nil日绘制柱形，页脚显示“有效N/7天”及均值，VoiceOver可读；负荷标为已观测负荷且不显示均值（含未完成与部分观测日）
