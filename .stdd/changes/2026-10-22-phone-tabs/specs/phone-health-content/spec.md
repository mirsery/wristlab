# Spec: phone-health-content

> Change: 2026-10-22-phone-tabs | Auto-generated Human View

## Requirements

### Requirement: 睡眠与活动内容

#### Scenario: SC-DATA-001

- **GIVEN** 有合成睡眠及活动报告，部分字段缺失
- **WHEN** 打开睡眠和活动Tab
- **THEN** SHALL展示已有睡眠详情和活动负荷、输出、覆盖、观测区间分钟及运动摘要；缺失为缺失，真实零保留，运动无元信息时用非时序编号，不输出内部ID或虚构类型和时间

### Requirement: 趋势与我的

#### Scenario: SC-DATA-002

- **GIVEN** 有历史、基线和心情记录或不足记录
- **WHEN** 切换趋势筛选及打开我的
- **THEN** SHALL提供原有日内、7/30日趋势、基线、有效日、周回顾和心情；我的可达连接、刷新、来源、生成时间、校准与全部现有设置，历史缺口断线且标实际日期

### Requirement: 状态和隐私一致

#### Scenario: SC-DATA-003

- **GIVEN** 真实空数据、校准、过期、刷新失败、演示或已清除数据
- **WHEN** 依次浏览各页并切换演示、刷新或清除
- **THEN** SHALL全页共享来源和最新报告；每页演示明确标记，退出或清除后旧详情失效；失败保留旧报告且显示失败，缺失与过期沿用原策略，不引入额外读取或泄漏
