# Spec: weight-goal

> Change: 2026-10-22-activity-weight-plan | Auto-generated Human View

## Requirements

### Requirement: 目标和录入一致性

#### Scenario: SC-WEIGHT-001

- **GIVEN** 创建或修改目标和手动体重
- **WHEN** 仅用kg录入/编辑并检查无lb切换；输入非有限值、非正数、未来体重日期或倒置期限
- **THEN** SHALL正确换算统一kg并拒绝无效输入；目标低于起始值、期限晚于开始；不自动提供目标或推荐速度；记录可编辑删除

### Requirement: 周趋势与缺失

#### Scenario: SC-WEIGHT-002

- **GIVEN** 同日多条、跨周/时区或不足3日的合成记录
- **WHEN** 查看和修订趋势
- **THEN** SHALL按最后采样日值统计，至少3个不同日才给周均；显示有效日和进行中，缺日不填值，双周均满足门槛才比较；编辑删除后重算

### Requirement: 暂停与目标差距

#### Scenario: SC-WEIGHT-003

- **GIVEN** 有目标与无/有最近体重
- **WHEN** 暂停、改目标或达到设定目标
- **THEN** SHALL保留历史，暂停可继续记录；有值才计算差距，达到后事实提示；不预测达标时间或生成热量预算

### Requirement: 迁移、原子写与清除

#### Scenario: SC-WEIGHT-004

- **GIVEN** 旧缓存、保存失败或正在刷新
- **WHEN** 保存计划/体重、重算或停止清除
- **THEN** SHALL兼容旧缓存，失败不覆盖旧数据；派生重算保留手动数据，停止清除删除所有计划体重执行记录且晚到任务不复活
