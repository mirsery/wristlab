# Spec: workout-completion

> Change: 2026-10-22-adaptive-movement | Auto-generated Human View

## Requirements

### Requirement: 时长与暂停

#### Scenario: SC-MATCH-001

- **GIVEN** 有效/无效事件、duration或旧缓存的合成workout
- **WHEN** 转换并重建运动记录
- **THEN** SHALL仅保存可验证活跃半开区间；旧字段缺失不按elapsed补时长；暂停不多算，不支持时显示待确认

### Requirement: 去重跨日与类型

#### Scenario: SC-MATCH-002

- **GIVEN** 多个来源、重复重叠、跨午夜及DST运动
- **WHEN** 匹配当天已采纳活动目标
- **THEN** SHALL同类型去重后对匹配活跃区间并集、按实际日裁剪；其他类型不猜匹配，不因多个来源重复计时

### Requirement: 完成阈值和缺失

#### Scenario: SC-MATCH-003

- **GIVEN** 实际时长在目标前后边界或无记录
- **WHEN** 查看进度
- **THEN** SHALL按秒比较、显示已记录分钟和比例，不取整提前完成；无记录保持unknown，手动确认不虚构或叠加实际分钟

### Requirement: 修订和人工冲突

#### Scenario: SC-MATCH-004

- **GIVEN** 已自动完成或手动确认/休息的目标
- **WHEN** 重复刷新、删除或修订workout
- **THEN** SHALL结果幂等且自动进度随真实记录回退并说明；人工状态和来源保留，不被自动结果覆写

### Requirement: 迁移事务与隔离

#### Scenario: SC-MATCH-005

- **GIVEN** 旧健康及PlanningState缓存、演示或清除并发
- **WHEN** 解码/保存/重建/清除/切换来源
- **THEN** SHALL兼容缺字段并保留手动计划，revision/来源/清除generation阻止旧回写；无新健康权限，体重计划不入Watch快照
