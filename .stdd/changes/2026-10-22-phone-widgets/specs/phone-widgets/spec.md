# Spec: phone-widgets

> Change: 2026-10-22-phone-widgets | Auto-generated Human View

## Requirements

### Requirement: 快照缓存校验

#### Scenario: SC-PHONEW-001

- **GIVEN** 有效真实快照（含补足到32768字节）、演示快照、损坏JSON、32769字节、未知schema、带数值的清除标记与有效清除标记
- **WHEN** 小组件读取phone-snapshot.json
- **THEN** SHALL 只接受有效真实快照与清除标记，其余视为无快照（等待手机）
- **AND** 无文件时同样为等待状态

### Requirement: 显示与时间线

#### Scenario: SC-PHONEW-002

- **GIVEN** 快照含当前、部分、单项过期、缺失与真实0的指标，以及无快照
- **WHEN** 生成组件时间线与各指标显示
- **THEN** SHALL 每个指标按ComplicationPresentation显示数值或原因（部分估算标注、过期隐藏数值），时间线为现在与各指标失效时刻且不含过去时刻
- **AND** 清除标记显示数据已清除且无数值
- **AND** 无快照时提示打开Wristlab刷新

### Requirement: 注册运行检查

#### Scenario: SC-PHONEW-003

- **GIVEN** iPhone小组件扩展的生产配置
- **WHEN** 在独立宿主中执行配置body
- **THEN** SHALL 每个配置输出成功标记，无fatal

### Requirement: 外观与隐私

#### Scenario: SC-PHONEW-004

- **GIVEN** 小/中、圆形、矩形、行内五种尺寸，有快照与无快照
- **WHEN** 渲染
- **THEN** SHALL 数值、原因（含圆形）、部分估算与更新时间可辨，深色背景下原因文字可读，锁屏视图标记隐私敏感
