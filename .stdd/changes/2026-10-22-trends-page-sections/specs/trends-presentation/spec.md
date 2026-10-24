# Spec: trends-presentation

> Change: 2026-10-22-trends-page-sections | Auto-generated Human View

## Requirements

### Requirement: 趋势主题分区保留现有功能、真实周期与来源边界。

#### Scenario: SC-TRENDUI-001

- **GIVEN** 报告与本地计划体重存在
- **WHEN** 查看健康、运动、体重分区
- **THEN** SHALL按设计归属显示，保留全部原能力，分别标明图表与回顾周期。

#### Scenario: SC-TRENDUI-002

- **GIVEN** 会话内已有分区、指标、周期和位置选择
- **WHEN** 切换主题、底部Tab或刷新
- **THEN** SHALL保留适用展示状态，不因切换额外读取健康或写入计划。

#### Scenario: SC-TRENDUI-003

- **GIVEN** 没有健康报告
- **WHEN** 访问三个主题
- **THEN** SHALL允许本地计划回顾与体重目标记录，健康缺失不补分或推断拒绝，周均门槛不变。

#### Scenario: SC-TRENDUI-004

- **GIVEN** 演示编辑、日内详情、旧报告或辅助字体
- **WHEN** 切换来源、清除、滚动与导航
- **THEN** SHALL失效旧弹窗、避免跨来源写入，状态清晰且内容不遮挡。
