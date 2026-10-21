# Spec: phone-widgets

> Change: 2026-10-22-phone-widgets | Auto-generated Human View

## Requirements

### Requirement: 快照缓存校验

#### Scenario: SC-PHONEW-001

- **GIVEN** 有效真实快照、演示快照、损坏JSON、超过64KB、未知schema与清除标记快照
- **WHEN** 小组件读取phone-snapshot.json
- **THEN** SHALL 只接受有效真实快照与清除标记，其余视为无快照（等待手机）
- **AND** 无文件时同样为等待状态

### Requirement: 显示与时间线

#### Scenario: SC-PHONEW-002

- **GIVEN** 快照含当前、部分、过期与缺失的指标
- **WHEN** 生成组件时间线与各指标显示
- **THEN** SHALL 每个指标按ComplicationPresentation显示数值或原因，时间线包含现在与各指标失效时刻且不含过去时刻
- **AND** 清除标记显示数据已清除且无数值

### Requirement: 注册与外观

#### Scenario: SC-PHONEW-003

- **GIVEN** iPhone小组件扩展的生产配置
- **WHEN** 在独立宿主中执行配置body
- **THEN** SHALL 每个配置输出成功标记，无fatal

#### Scenario: SC-PHONEW-004

- **GIVEN** 小/中、圆形、矩形、行内五种尺寸，有快照与无快照
- **WHEN** 渲染
- **THEN** SHALL 数值、原因与更新时间可辨，锁屏视图标记隐私敏感
