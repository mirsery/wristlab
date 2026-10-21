# Spec: metric-contributions

> Change: 2026-10-21-metric-insights | Auto-generated Human View

## Requirements

### Requirement: 准备度贡献分解

#### Scenario: SC-CONTRIB-001

- **GIVEN** 准备度有数值且未过期，contributions含hrv、baselineHRV、zHRV、rhr、baselineRHR、zRHR
- **WHEN** 生成贡献行
- **THEN** SHALL 按HRV、静息心率顺序输出两行，各含当前值、个人基线与差值（当前值与基线各按单位取整后相减）
- **AND** zHRV≥0.5显示“推高准备度”，≤−0.5显示“拉低准备度”，其余显示“接近个人基线”
- **AND** zRHR同规则；zRHR为正表示静息心率低于基线

### Requirement: 压力贡献分解

#### Scenario: SC-CONTRIB-002

- **GIVEN** 压力有数值且未过期，quality为complete，contributions含hr、baselineHR、zHR、zHRV
- **WHEN** 生成贡献行
- **THEN** SHALL 输出心率行（当前值、基线、差值、推高/降低压力/接近个人基线）及仅含方向与效果的HRV行
- **AND** zHRV为正表示HRV低于基线、推高压力
- **AND** 跨睡眠边界的partial+sourceConflict桶仍用到HRV，照常列HRV行
- **AND** zHRV非有限值时不列HRV行

#### Scenario: SC-CONTRIB-003

- **GIVEN** 压力为HR-only（reasons含hrOnly）或mode为activity
- **WHEN** 生成贡献行
- **THEN** SHALL 只输出心率行，不输出HRV行

### Requirement: 缺失与过期不输出

#### Scenario: SC-CONTRIB-004

- **GIVEN** 指标无数值、已过期，或某输入缺少当前值、基线或z中任一键
- **WHEN** 生成贡献行
- **THEN** SHALL 不为该输入输出行；无数值或过期时结果为空
- **AND** 任何输出文本不含z值、zHRV等内部键名

### Requirement: 规格分段短句

#### Scenario: SC-CONTRIB-005

- **GIVEN** 准备度或压力显示整数位于各分段边界，或电量有数值，或指标无数值
- **WHEN** 取分段短句
- **THEN** SHALL 准备度0–32为“较低”、33–66为“接近个人常态”、67–100为“较高”；压力0–19“低”、20–59“常态”、60–79“偏高”、80–100“高”
- **AND** 电量返回nil，无数值返回nil
- **AND** 真实0返回最低分段

#### Scenario: SC-CONTRIB-006

- **GIVEN** 首页准备度卡与压力卡有数值
- **WHEN** 渲染首页
- **THEN** SHALL 准备度标题显示“准备度”加分段短句，压力卡显示分段；不出现“给自己一点休息”等建议性文案
- **AND** 详情页贡献行替代原始contributions键列表
