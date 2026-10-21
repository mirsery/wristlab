# 心情记录与压力对照 - 技术设计（Gate 1/2已确认，实施中）

## Context

用户希望看心情与压力的关系。生理压力只表示心率/HRV相对基线的唤醒，不能区分愉快与不愉快，002 A-006禁止推断心理状态。HealthKit自iOS 18提供HKStateOfMind（kind：即时情绪/每日心情；valence −1…1；valenceClassification 1–7；labels 1–38；associations 1–18；SDK头文件已核对）。项目最低iOS 17。HealthKitReader把评分类型放在`types`列表并用锚点增量读取，`anchors.count != types.count`会触发全量重读。报告stressTimeline目前只保留当天的5分钟桶。

## Decisions

### 1. 心情单独读取，只在内存
**方案**：HealthKitReader新增`authorizeMoods()`与`readMoods(from:)`（`HKSampleQueryDescriptor`+`.stateOfMind`），均在`#available(iOS 18)`内；不加入`types`，不改锚点与仓库；DashboardModel在用户点“连接心情记录”后记住已请求（UserDefaults），每次刷新读取最近7个分析日的记录，只放内存。
**为什么**：不触发评分数据全量重读，不改仓库schema或Watch同步；心情不参与任何计算。
**备选**：并入HealthRecord与仓库——需要新HealthKind、改schema与锚点，收益只是离线缓存，拒绝。

### 2. Core的MoodEntry与展示模型
**方案**：Core新增与HealthKit无关的MoodEntry（id、时间、kind、valence、分类与标签/关联项原始整数），MoodNames提供固定中文名（越界“未知”），MoodOverview生成最近7个分析日、asOf之前、去重倒序的行，以及当天即时情绪时刻。
**为什么**：边界规则要求平台无关逻辑在Core，可单测。

### 3. 压力配对规则
**方案**：即时情绪：先取包含记录时刻的有值桶，否则取结束时刻在记录前15分钟内的最近有值桶（与当前压力时效规则一致），从不借用之后的桶，否则为空；运动桶标注运动中。每日心情：当天（分析时区半开日）有值桶的中位数，无值为空；当天进行中注明截至目前；晚于报告的记录注明刷新后配对。显示压力整数与002分段，措辞为“生理压力”。
**为什么**：压力桶15分钟后即视为过期（002），配对窗口与之一致；不插值、不外推。

### 4. stressTimeline扩到最近7个分析日
**方案**：引擎输出`timeline.filter { start >= D-6 }`；DayTimeline本来按可见当天过滤，显示不变；`report.stress`仍取最后一个桶。
**为什么**：配对最近7天的心情需要当时的压力桶。报告略增大（每天≤288桶）。

### 5. 展示
首页“心情记录”卡片三态（未连接/无记录/列表），每行：时间、类型、分类、标签、关联、同时段压力或“同时段无压力估算”；压力图在当天记录时刻画竖虚线并在图例注明“心情记录”。声明：心情为自报，不从心率或压力推算；并列显示不表示因果。iOS 17不显示卡片。演示模式使用明确标记的合成心情。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 并列被理解为因果 | 卡片与图例声明；不计算相关 |
| 授权提示打扰 | 仅用户点击连接时请求；空读取不推断拒绝 |
| stressTimeline变长影响数值 | 只改输出过滤；当前压力与评分测试不变，TIMELINE-001更新桶数断言 |
| iOS 17不可用 | 运行时#available，卡片隐藏 |
| 报告JSON变大（每天至多288个桶，演示约436KB） | 只影响iPhone本地仓库写盘，不进Watch快照；后续如有性能问题再做摘要 |
| 刷新与清除并发 | loadMoods按generation丢弃过期结果；停止读取清空并忘记连接请求 |
