# 讲清楚已有估算：执行切片

依赖：S1、S3只依赖既有报告模型，可独立；S2需先扩展EnergyReport与引擎。按S1→S2→S3顺序执行，每片含Core模型（RED→GREEN）及其iPhone界面，保证每片有新增测试。全自动长程模式，Gate 3人工确认。

| 切片 | Capability / TC | 风险 | 产出 |
| --- | --- | --- | --- |
| S1 贡献分解与分段 | metric-contributions：CONTRIB-001～006 | 中（措辞） | InsightPresentation.swift的MetricContributions、MetricTier；MetricDetailView贡献行；首页准备度标题与压力卡分段 |
| S2 一天的节奏 | daily-timeline：TIMELINE-001～005 | 中（引擎输出、旧缓存解码） | EnergyReport两个Optional区间；HealthEngine写入；DayTimeline；首页电量+压力两张图 |
| S3 睡眠详情与趋势 | sleep-and-trend-detail：SLEEPUI-001～004、TREND-001～002 | 低 | SleepBreakdown、TrendSeries；SleepDetailView；7日趋势Picker |

风险评分：经验库无severity high且相关的匹配（EXP-003为选源，不相关）；EXP-001（跨界面不一致）提示过期与演示状态需统一，已写入S1/S3规格。
