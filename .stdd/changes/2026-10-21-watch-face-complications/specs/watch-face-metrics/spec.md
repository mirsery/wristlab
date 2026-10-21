# Spec: watch-face-metrics

> Change: 2026-10-21-watch-face-complications | Auto-generated Human View

## Requirements

### Requirement: 四个固定组件及布局兼容性

#### Scenario: SC-FACE-001

- **GIVEN** 已安装Watch应用和Widget扩展
- **WHEN** 系统枚举组件配置
- **THEN** SHALL 提供WristlabEnergy、WristlabReadiness、WristlabStress、WristlabOverview四个kind；Energy保留原kind且三种单指标支持圆形、矩形、行内、角落四种family，Overview仅支持矩形

### Requirement: 各指标使用同一快照、独立映射状态

#### Scenario: SC-FACE-002

- **GIVEN** 同一有效healthKit快照有三个不同的0–100数值
- **WHEN** 分别显示三个组件及总览
- **THEN** SHALL 每格读取对应字段并保留quality、更新时间；不得独立计算分数或交叉取错字段

#### Scenario: SC-FACE-003

- **GIVEN** 有效新鲜快照中的某指标值恰好为0
- **WHEN** 渲染该指标
- **THEN** SHALL 显示0，不能把真实零当作缺失

#### Scenario: SC-FACE-004

- **GIVEN** 快照存在但指标正在校准、输入不足、不支持或失败
- **WHEN** 渲染相应指标
- **THEN** SHALL 分别显示校准中、数据不足、暂不支持或读取失败及破折号，且无数值Gauge；总览中其他有效指标仍可显示

#### Scenario: SC-FACE-005

- **GIVEN** 可用指标quality为partial
- **WHEN** 渲染指标
- **THEN** SHALL 保留数值并在完整可访问性描述及可容纳文字的布局标为部分估算

### Requirement: 过期边界、空缓存和清除语义

#### Scenario: SC-FACE-006

- **GIVEN** 快照或某指标已过期、或者时间在未来
- **WHEN** 渲染各family
- **THEN** SHALL 将受影响当前值显示为破折号并标已过期；单项过期不屏蔽仍新鲜的其他指标；快照过期屏蔽全部，等于validUntil和computedAt+3600秒时沿用既有严格大于边界

#### Scenario: SC-FACE-007

- **GIVEN** 无缓存、损坏JSON、schema不支持或clearData标记
- **WHEN** 读取并展示组件
- **THEN** SHALL 显示等待手机或数据已清除的中性空状态，不崩溃、不显示旧值、无真实健康日志

#### Scenario: SC-FACE-008

- **GIVEN** 真实组件读取到source为demo的缓存
- **WHEN** 渲染组件
- **THEN** SHALL 拒绝把演示缓存显示为真实分数；应用内独立预览可使用标注合成演示的固定样例，但不写入真实App Group

### Requirement: 时间线和系统外观适配

#### Scenario: SC-FACE-009

- **GIVEN** 新鲜快照及其单指标存在未来失效时刻
- **WHEN** 生成Widget时间线
- **THEN** SHALL 输出now及各有效失效边界后一秒的唯一有序entry，包含快照60分钟边界；请求系统择机刷新且不承诺准点执行

#### Scenario: SC-FACE-010

- **GIVEN** 圆形/矩形/行内/角落及系统着色或低亮度场景
- **WHEN** 渲染预览或实际组件
- **THEN** SHALL 数值与状态可辨且VoiceOver含标题、数值或原因、更新时间；组件遵循系统背景与着色，不仅依赖颜色表达状态

### Requirement: 安全的Watch组件路由

#### Scenario: SC-FACE-011

- **GIVEN** 点击三种单指标组件或矩形总览
- **WHEN** 处理wristlab://complication/energy、readiness、stress或overview
- **THEN** SHALL 打开Watch应用对应指标详情或首页总览；冷启动与已打开两种场景均保留选择，不触发HealthKit授权或数据写入

#### Scenario: SC-FACE-012

- **GIVEN** URL的scheme/host/路径不匹配或带未知query、fragment、用户信息或port
- **WHEN** Watch处理入口URL
- **THEN** SHALL 安全回到首页总览，不执行命令、不接受任意路径、不改变健康数据
