# Spec: phone-today-care

> Change: 2026-10-24-phone-care-layout | Auto-generated Human View

## Requirements

### Requirement: 标准字号下今日关怀双列卡片顶边对齐、等高，说明全文保留。

#### Scenario: PCL-001

- **GIVEN** 标准字号，身体电量为校准中 9/14 天（合成）长说明，生理压力为短状态
- **WHEN** 渲染今日关怀两列卡片
- **THEN** SHALL 两卡顶边差与高度差均不超过 1pt，各自状态、说明全文和查看详情入口可见且可点击。

#### Scenario: PCL-002

- **GIVEN** 最大辅助字号与同一长短混合数据
- **WHEN** 渲染今日关怀卡片
- **THEN** SHALL 保持单列，电量卡完全位于压力卡上方不重叠，文本不截断且两卡均可进入详情。

### Requirement: 今天页滚动内容不与状态栏重叠，末尾内容可越过底部页签栏。

#### Scenario: PCL-003

- **GIVEN** 正式 App 今天页（合成演示）已向上滚动，使页头位于状态栏区域
- **WHEN** 截取屏幕
- **THEN** SHALL 状态栏区域只显示与页面同色的背板和系统状态栏，不透出页面文字；背板不可交互且对 VoiceOver 隐藏。

#### Scenario: PCL-004

- **GIVEN** 正式 App 今天页
- **WHEN** 滚动到底
- **THEN** SHALL 最后一张卡片底边不低于页签栏顶边，五个页签与三张关怀卡的导航保持原行为。
