# Spec: daily-timeline

> Change: 2026-10-21-metric-insights | Auto-generated Human View

## Requirements

### Requirement: 引擎输出电量驱动区间

#### Scenario: SC-TIMELINE-001

- **GIVEN** 合成记录含跨午夜主睡眠、当日午后小睡与当日运动
- **WHEN** HealthEngine评估当日报告
- **THEN** SHALL 在energy.asleepIntervals与energy.workoutIntervals写入电量重放使用的区间，并裁剪到分析日起点至asOf
- **AND** 电量点、准备度、压力数值与改动前一致

### Requirement: 时间线区段

#### Scenario: SC-TIMELINE-002

- **GIVEN** 报告含睡眠与运动区间，部分落在分析日之外或长度为0
- **WHEN** 生成DayTimeline
- **THEN** SHALL 输出按开始时间排序、裁剪到分析日起点至asOf、长度大于0的睡眠与运动区段，并区分类型
- **AND** 分析日按固定分析时区的日历日，夏令时切换日可为23或25小时

#### Scenario: SC-TIMELINE-003

- **GIVEN** 旧仓库状态JSON的EnergyReport缺少两个区间字段
- **WHEN** 解码并生成DayTimeline
- **THEN** SHALL 解码成功、区段为空、不崩溃

### Requirement: 曲线断线

#### Scenario: SC-TIMELINE-004

- **GIVEN** 当天压力桶存在时间空隙、无数值桶与运动桶
- **WHEN** 生成压力分段
- **THEN** SHALL 只把首尾相接且都有数值的桶连成同一段，空隙或无数值处断开；运动桶标记为运动中
- **AND** 点位于桶中点，数值取显示整数

#### Scenario: SC-TIMELINE-005

- **GIVEN** 电量点序列中间有nil
- **WHEN** 生成电量分段
- **THEN** SHALL 在nil处断开，不插值、不画0
- **AND** 电量当前值不可显示（覆盖不足、过期、校准或缺失）时不输出电量曲线，界面改为显示原因
- **AND** 分析日已结束时标记为非今天，界面显示报告日期
