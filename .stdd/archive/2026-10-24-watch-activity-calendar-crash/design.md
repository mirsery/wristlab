# 活动摘要calendar闪退修复设计

## Context
2401在实体Watch可安装但反复闪退。定向普通启动控制台已经RED：NSInvalidArgumentException，Date components require a calendar，退出1。未导出健康容器或原始控制台流。SDK HKQuery.h要求公历era/year/month/day。DailyActivityReader当前dateComponents只提取这些数字，没有携calendar。手机另报“无数据，刷新已取消”，独立诊断，不借此推断授权拒绝。

## Decisions
1. 提取适配器内部summaryDateComponents(at:clock:)作为生产查询唯一入口，显式设置clock.calendar与同一timeZone，公历/日期归属不变。不改Core评分或跨设备拼数据。
2. 先提取原行为并在无健康读取的Watch隔离宿主调用真实HKQuery谓词，复现相同异常；再补calendar/timeZone。生产源码直接参与测试，不靠演示绕开适配器。
3. 扩展现有Widget注册宿主的Watch路径，加入生产适配器合成日期契约检查及ACAL标记；iPhone宿主不增加HealthKit调用。午夜/上海/纽约/DST字段对比及重复构造，不执行query/store/authorize。
4. 同包2402覆盖并普通启动，禁止卸载/清缓存。保留既有活动连接标志，让原刷新路径验证修复；启动回执与持续运行/用户反馈分别记录。

## Architecture
系统时区 → AnalysisClock → DailyActivityReader.summaryDateComponents → HKQuery谓词 → 原HKActivitySummaryQuery；测试宿主复用同一日期构造和真实谓词，不读取记录。

## Risks / Trade-offs
- Objective-C NSException不受Swift do/catch保护：在构造前满足平台契约，不能加catch遮蔽。
- 只测DTO会漏真机契约：平台宿主运行生产参数。
- 历史缓存触发重复崩溃：保留缓存并修调用，不停用功能作为修复。
- 手机取消另有来源：不随手改Dashboard或评分，仅诊断；需要修复时另明确设计。
- 无固定后台刷新承诺；无新依赖/权限/通知/云。

Gate 1用户“确认，按这个范围修复”；Gate 2已展示具体calendar/timeZone+SDK回归+2402覆盖方案，用户“确认，实施这个修复方案”。仅本次修复，不代批Gate 3。
