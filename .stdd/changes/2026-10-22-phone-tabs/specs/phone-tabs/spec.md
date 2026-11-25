# Spec: phone-tabs

> Change: 2026-10-22-phone-tabs | Auto-generated Human View

## Requirements

### Requirement: 五Tab与浏览状态

#### Scenario: SC-NAV-001

- **GIVEN** 已打开真实或演示报告
- **WHEN** 进入详情、滚动并往返切换Tab
- **THEN** SHALL显示今天、睡眠、活动、趋势、我的，初始为今天；当前会话保留各页路径、滚动与趋势筛选，不重复触发读取或授权

### Requirement: 今天精简与入口

#### Scenario: SC-NAV-002

- **GIVEN** 报告可用或部分缺失
- **WHEN** 打开今天并点击摘要
- **THEN** SHALL只包含核心三指标、睡眠和活动摘要及数据状态；三指标可进入解释详情，主题摘要切到对应Tab，完整曲线及列表仅在主题页

### Requirement: 大字体与读屏

#### Scenario: SC-NAV-003

- **GIVEN** 合成完整报告与空报告
- **WHEN** 用辅助功能字体、VoiceOver与减少动态效果浏览五Tab
- **THEN** SHALL保留所有入口，不截断关键值和操作；可读指标、单位、日期、状态，系统减少动态效果可用
