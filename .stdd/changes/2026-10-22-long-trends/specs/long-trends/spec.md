# Spec: long-trends

> Change: 2026-10-22-long-trends | Auto-generated Human View

## Requirements

### Requirement: 35日逐日历史

#### Scenario: SC-LONG-001

- **GIVEN** 合成记录覆盖23个分析日（少于35日），部分日缺夜间HRV或静息心率，且白天另有HRV
- **WHEN** HealthEngine评估当日报告
- **THEN** SHALL 输出以今天为终点的35个分析日history，逐日含nightHRV与restingHeartRate，缺输入的日为nil
- **AND** 夜间HRV只取主睡眠内样本且至少2条
- **AND** 准备度、压力、电量数值与改动前一致（电量点校验和由TC-TIMELINE-001覆盖）

### Requirement: 个人基线区间

#### Scenario: SC-LONG-002

- **GIVEN** 今天准备度为夜间模式，前60个分析日内今天主睡眠来源的有效夜间成对日分别为20、17（另有其他来源夜晚）与13；另一例今天无主睡眠
- **WHEN** 计算personalRanges
- **THEN** SHALL 夜间模式且至少14日时输出HRV区间exp(中位数±0.5尺度)与静息心率区间中位数±0.5尺度及有效日数，与今天准备度的baselineDays和基线中心一致；不足14日或今天为日间回退时为nil
- **AND** 只计今天主睡眠来源的夜晚，不混合来源
- **AND** 区间边缘对应准备度z=±0.5；无效配对不计入，校准期baselineDays不变

### Requirement: 7/30日趋势

#### Scenario: SC-LONG-003

- **GIVEN** 35日history中有缺日与nil值
- **WHEN** 按30日生成准备度、夜间HRV、静息心率序列
- **THEN** SHALL 输出以报告日为终点的30个分析日，缺失为nil，有效天数与均值只计非nil
- **AND** 7日行为与上一轮一致

#### Scenario: SC-LONG-004

- **GIVEN** 旧缓存JSON的DayOverview与HealthReport缺少新字段，或history只有7日
- **WHEN** 解码
- **THEN** SHALL 解码成功，新字段为nil；7日旧history仍生成30个日期位置，近7日回顾此前28日为空

#### Scenario: SC-LONG-005

- **GIVEN** 首页趋势卡片
- **WHEN** 切换7/30日与五个指标
- **THEN** SHALL 只为非nil日绘制，HRV/静息心率在有个人基线区间时显示区间带并注明来源与有效夜晚数，无区间时说明原因，VoiceOver可读
