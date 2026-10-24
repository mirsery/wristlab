# Spec: generated-week

> Change: 2026-10-22-adaptive-movement | Auto-generated Human View

## Requirements

### Requirement: 首周确定性生成

#### Scenario: SC-AUTO-001

- **GIVEN** 已填经验、类型、可用日期及上限
- **WHEN** 无健康记录或填写典型周分钟后生成
- **THEN** SHALL按design公式产生同输入同输出的草案，逐日不超容量且总量一致；不将缺记录补零或体重期限反推分钟

### Requirement: 预览采纳与历史

#### Scenario: SC-AUTO-002

- **GIVEN** 旧手动计划或已完成历史存在
- **WHEN** 预览、修改、拒绝或采纳新周
- **THEN** SHALL确认前不覆盖；确认后仅影响未来未处理日，保留版本/原目标，首周不补过去日期

### Requirement: 下一周调整

#### Scenario: SC-AUTO-003

- **GIVEN** 完整结束周及反馈/完成证据或缺失
- **WHEN** 生成/采纳下周草案
- **THEN** SHALL只按design门槛提出±5分钟或保持，缺证据不加量，休息不算完成、不补课，采纳前不生效

### Requirement: 目标周期与页面

#### Scenario: SC-AUTO-004

- **GIVEN** 有减重目标、截止日期或暂停
- **WHEN** 查看向导、今天和周回顾
- **THEN** SHALL五Tab入口可达，目标日期只控制周期和回顾，不承诺减脂；无期限堆积补练，暂停不重新自动生成
