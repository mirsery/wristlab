# Spec: activity-plan

> Change: 2026-10-22-activity-weight-plan | Auto-generated Human View

## Requirements

### Requirement: 配置与周安排

#### Scenario: SC-PLAN-001

- **GIVEN** 尚无计划或已有安排
- **WHEN** 设置偏好、日期和时长或编辑计划
- **THEN** SHALL只按用户配置形成安排；编辑不覆盖过去或已处理日快照；暂停后不再给每日调整

### Requirement: 解释与降级

#### Scenario: SC-PLAN-002

- **GIVEN** 当天安排存在且准备度为低分、正常分、缺失、校准或旧数据
- **WHEN** 查看每日安排和调整选项
- **THEN** SHALL按design规则优先级展示；只在当前有效低准备度提供休息或已预设轻量选项，其他状态保持原定安排并解释；不自动加量或换算分钟

### Requirement: 执行与回顾

#### Scenario: SC-PLAN-003

- **GIVEN** 有当周计划，含跨日及DST边界
- **WHEN** 完成、重复完成、替换、休息或撤销
- **THEN** SHALL按固定时区计划日幂等记录；替换不等于完成，休息单列；周回顾保留原安排，未完成不补课

### Requirement: 页面、演示与隐私

#### Scenario: SC-PLAN-004

- **GIVEN** 空状态或真实/演示数据及大字体
- **WHEN** 在现有五Tab浏览和切换来源
- **THEN** SHALL各入口可达且单位状态可读；演示独立，退出不残留；不发送体重到Watch/Widget，不新增健康授权，不把手动完成标为自动识别
