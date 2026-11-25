# Spec: watch-daily-activity

> Change: 2026-10-24-watch-activity-calendar-crash | Auto-generated Human View

## Requirements

### Requirement: 活动摘要查询满足平台日历契约且保持系统日。

#### Scenario: ACAL-001

- **GIVEN** 生产适配器构造当天活动摘要日期
- **WHEN** 将日期传给真实HKQuery活动摘要谓词
- **THEN** SHALL显式携带Gregorian calendar和同一系统时区、era/year/month/day，谓词构造无NSException且不请求授权或读取健康记录。

#### Scenario: ACAL-002

- **GIVEN** UTC、上海、纽约的近午夜和23/25小时DST合成时刻
- **WHEN** 构造活动摘要日期和谓词
- **THEN** SHALL日期字段与对应AnalysisClock完全一致，不用UTC日或评分日替代系统日。

#### Scenario: ACAL-003

- **GIVEN** 用户原活动连接和缓存保留且前台读取会触发摘要
- **WHEN** 同包覆盖2402后普通启动并刷新
- **THEN** SHALL不再因缺少calendar终止进程，保留原数据和连接选择、不清缓存或改权限；真实运行及活动结果须由设备或用户反馈确认。
