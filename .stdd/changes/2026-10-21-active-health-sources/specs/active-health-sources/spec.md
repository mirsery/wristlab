# Spec: active-health-sources

> Derived from canonical/specs/code/active-health-sources.yaml; Gate1/2及用户追加范围见phase-context。

## Requirements

### Requirement: 历史失活来源

#### Scenario: SC-SOURCE-001

- **GIVEN** 旧优先来源仅在60日计算窗口外有记录，另一个来源窗口内有有效记录
- **WHEN** 自动选源并评估报告
- **THEN** SHALL 选择窗口内有效来源，不让历史来源遮挡当前压力桶

### Requirement: 保留既有优先级

#### Scenario: SC-SOURCE-002

- **GIVEN** 多个来源均在窗口内有有效记录
- **WHEN** 自动选源
- **THEN** SHALL 继续按Watch、第三方、iPhone及group顺序固定单组，不按每桶填补缺口

### Requirement: 明确偏好优先

#### Scenario: SC-SOURCE-003

- **GIVEN** 用户明确指定的来源仍有保留记录，即使其不在当前窗口
- **WHEN** 选择HR、RHR或HRV来源
- **THEN** SHALL 尊重明确偏好，不静默改用户配置；不同类型独立选择

### Requirement: 边界及完整历史

#### Scenario: SC-SOURCE-004

- **GIVEN** 候选来源有窗口边界、窗口外和未来样本
- **WHEN** 构建候选组及输出选定组记录
- **THEN** SHALL 用有效样本end在起点至asOf闭区间判定候选；排除未来；返回选定组全部保留有效历史

### Requirement: 确实缺失与校准

#### Scenario: SC-SOURCE-005

- **GIVEN** 没有自动候选或选中当前HR但无14日有效基线
- **WHEN** 运行评分
- **THEN** SHALL 分别保持必要输入缺失或校准，不生成默认数值

### Requirement: 来源切换一致重建

#### Scenario: SC-SOURCE-006

- **GIVEN** 持久化报告使用历史失活来源，刷新后选择有效来源
- **WHEN** 仓库apply并发布快照
- **THEN** SHALL 重算报告与电量，sourceSignature变化时推进epoch，并让快照指标与报告一致

### Requirement: 夜间基线不足

#### Scenario: SC-EXPLAIN-001

- **GIVEN** 已有主睡眠及配对夜间输入，但历史不足14个有效日
- **WHEN** 构建无seed电量估算
- **THEN** SHALL 使用calibrating、baselineNotReady及真实baselineDays，不错误归因缺少睡眠

### Requirement: 必要夜间输入缺失

#### Scenario: SC-EXPLAIN-002

- **GIVEN** 主睡眠、夜间HRV或对应RHR缺少一种
- **WHEN** 构建无seed电量估算
- **THEN** SHALL 分别给出必要输入原因，不造分数或放松门槛

### Requirement: 双端可见且同一解释

#### Scenario: SC-EXPLAIN-003

- **GIVEN** 同步包含校准或缺失原因的指标
- **WHEN** 手机/Watch首页及详情展示
- **THEN** SHALL 首页直接说明原因与X/14进度，详情提供操作建议；同步沿用原schema与理由字段

### Requirement: 状态优先与未知回退

#### Scenario: SC-EXPLAIN-004

- **GIVEN** 真实零、过期、低覆盖、未知原因或无快照
- **WHEN** 生成说明及展示值
- **THEN** SHALL 保留真实0、过期隐藏旧值并说明刷新、覆盖不足说明门槛，未知原因中性回退且不推断拒绝权限
