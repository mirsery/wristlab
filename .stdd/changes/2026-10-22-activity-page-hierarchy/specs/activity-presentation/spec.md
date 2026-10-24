# Spec: activity-presentation

> Change: 2026-10-22-activity-page-hierarchy | Auto-generated Human View

## Requirements

### Requirement: 活动页突出今日任务，整合管理入口并保留原功能和状态语义。

#### Scenario: SC-ACTUI-001

- **GIVEN** 已有手动、自动、未来生效或暂停安排，或没有计划
- **WHEN** 进入活动页
- **THEN** SHALL先显示今日实际模式与任务，再显示本周摘要和活动详情入口；空态只有一个建立计划主入口，不把未来计划说成今天模式。

#### Scenario: SC-ACTUI-002

- **GIVEN** 从活动进入统一管理计划页
- **WHEN** 查看自动/手动分段、生成预览、取消或明确保存切换
- **THEN** SHALL保留所有原有计划操作，浏览和取消不写入，只有明确采纳或保存才按原规则生效。

#### Scenario: SC-ACTUI-003

- **GIVEN** 健康运动证据缺失、修订或存在人工完成/休息
- **WHEN** 查看今日任务和健康匹配进度
- **THEN** SHALL独立显示健康分钟和人工状态，缺失保持待确认且原因可达，不改变历史或生成公式。

#### Scenario: SC-ACTUI-004

- **GIVEN** 默认或辅助字体、窄屏、空/旧报告或演示状态
- **WHEN** 滚动、进入负荷详情、刷新、Tab往返或切换来源
- **THEN** SHALL保持内容可读与详情可达，保留覆盖度/缺失说明，不用固定顶部区域遮挡内容；来源变化不沿用旧表单。
