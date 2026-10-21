# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
Core纯展示模型与真实HealthEngine集成全部使用合成输入，先写失败测试（RED）再实现（GREEN）。界面只做布局，以静态检查、模拟器合成演示截图和人工视觉/VoiceOver审阅验证，不写镜像UI的单测。已有资产：50 Core + 5 workspace测试、12份数值金例、DemoData合成报告；全部须保持通过且金例不变。真机显示由用户验收，模拟器结果不代表真机。

## 详细测试案例

### SC-CONTRIB-001 — 准备度贡献分解

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-001 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-001 |
| **优先级** | P0 |
| **预置条件** | 准备度有数值且未过期，contributions含hrv、baselineHRV、zHRV、rhr、baselineRHR、zRHR |
| **输入** | 生成贡献行 |
| **预期结果** | SHALL 按HRV、静息心率顺序输出两行，各含当前值、个人基线与差值（当前值与基线各按单位取整后相减）；zHRV≥0.5显示“推高准备度”，≤−0.5显示“拉低准备度”，其余显示“接近个人基线”；zRHR同规则；zRHR为正表示静息心率低于基线 |
| **测试函数** | readinessContributionsShowBaselineDeltaAndEffect_TC_CONTRIB_001 |
| **层次** | Swift Testing Core单元 |

### SC-CONTRIB-002 — 压力贡献分解

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-002 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-002 |
| **优先级** | P0 |
| **预置条件** | 压力有数值且未过期，quality为complete，contributions含hr、baselineHR、zHR、zHRV |
| **输入** | 生成贡献行 |
| **预期结果** | SHALL 输出心率行（当前值、基线、差值、推高/降低压力/接近个人基线）及仅含方向与效果的HRV行；zHRV为正表示HRV低于基线、推高压力；跨睡眠边界的partial+sourceConflict桶仍用到HRV，照常列HRV行；zHRV非有限值时不列HRV行 |
| **测试函数** | stressContributionsShowHeartRateAndHRVDirection_TC_CONTRIB_002 |
| **层次** | Swift Testing Core单元 |

### SC-CONTRIB-003 — 压力贡献分解

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-003 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-003 |
| **优先级** | P0 |
| **预置条件** | 压力为HR-only（reasons含hrOnly）或mode为activity |
| **输入** | 生成贡献行 |
| **预期结果** | SHALL 只输出心率行，不输出HRV行 |
| **测试函数** | stressHROnlyAndActivityOmitHRVRow_TC_CONTRIB_003 |
| **层次** | Swift Testing Core单元 |

### SC-CONTRIB-004 — 缺失与过期不输出

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-004 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-004 |
| **优先级** | P0 |
| **预置条件** | 指标无数值、已过期，或某输入缺少当前值、基线或z中任一键 |
| **输入** | 生成贡献行 |
| **预期结果** | SHALL 不为该输入输出行；无数值或过期时结果为空；任何输出文本不含z值、zHRV等内部键名 |
| **测试函数** | contributionsOmitMissingStaleAndInternalKeys_TC_CONTRIB_004 |
| **层次** | Swift Testing Core单元 |

### SC-CONTRIB-005 — 规格分段短句

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-005 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-005 |
| **优先级** | P0 |
| **预置条件** | 准备度或压力显示整数位于各分段边界，或电量有数值，或指标无数值 |
| **输入** | 取分段短句 |
| **预期结果** | SHALL 准备度0–32为“较低”、33–66为“接近个人常态”、67–100为“较高”；压力0–19“低”、20–59“常态”、60–79“偏高”、80–100“高”；电量返回nil，无数值返回nil；真实0返回最低分段 |
| **测试函数** | tierLabelsFollowScoringBoundaries_TC_CONTRIB_005 |
| **层次** | Swift Testing Core单元（参数化边界） |

### SC-CONTRIB-006 — 规格分段短句

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-CONTRIB-006 |
| **对应 Spec** | metric-contributions/spec.md → Scenario: SC-CONTRIB-006 |
| **优先级** | P1 |
| **预置条件** | 首页准备度卡与压力卡有数值 |
| **输入** | 渲染首页 |
| **预期结果** | SHALL 准备度标题显示“准备度”加分段短句，压力卡显示分段；不出现“给自己一点休息”等建议性文案；详情页贡献行替代原始contributions键列表 |
| **测试函数** | —（静态检查首页无建议文案 + 模拟器合成演示截图视觉检查） |
| **层次** | 静态/模拟器/人工 |

### SC-TIMELINE-001 — 引擎输出电量驱动区间

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TIMELINE-001 |
| **对应 Spec** | daily-timeline/spec.md → Scenario: SC-TIMELINE-001 |
| **优先级** | P0 |
| **预置条件** | 合成记录含跨午夜主睡眠、当日午后小睡与当日运动 |
| **输入** | HealthEngine评估当日报告 |
| **预期结果** | SHALL 在energy.asleepIntervals与energy.workoutIntervals写入电量重放使用的区间，并裁剪到分析日起点至asOf；电量点、准备度、压力数值与改动前一致 |
| **测试函数** | engineExposesEnergyDriverIntervalsWithoutChangingValues_TC_TIMELINE_001 |
| **层次** | Swift Testing 真实HealthEngine集成 |

### SC-TIMELINE-002 — 时间线区段

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TIMELINE-002 |
| **对应 Spec** | daily-timeline/spec.md → Scenario: SC-TIMELINE-002 |
| **优先级** | P0 |
| **预置条件** | 报告含睡眠与运动区间，部分落在分析日之外或长度为0 |
| **输入** | 生成DayTimeline |
| **预期结果** | SHALL 输出按开始时间排序、裁剪到分析日起点至asOf、长度大于0的睡眠与运动区段，并区分类型；分析日按固定分析时区的日历日，夏令时切换日可为23或25小时 |
| **测试函数** | dayTimelineClipsSortsAndTypesSpans_TC_TIMELINE_002 |
| **层次** | Swift Testing Core单元 |

### SC-TIMELINE-003 — 时间线区段

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TIMELINE-003 |
| **对应 Spec** | daily-timeline/spec.md → Scenario: SC-TIMELINE-003 |
| **优先级** | P0 |
| **预置条件** | 旧仓库状态JSON的EnergyReport缺少两个区间字段 |
| **输入** | 解码并生成DayTimeline |
| **预期结果** | SHALL 解码成功、区段为空、不崩溃 |
| **测试函数** | legacyEnergyReportDecodesWithoutSpans_TC_TIMELINE_003 |
| **层次** | Swift Testing Core单元（旧JSON解码） |

### SC-TIMELINE-004 — 曲线断线

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TIMELINE-004 |
| **对应 Spec** | daily-timeline/spec.md → Scenario: SC-TIMELINE-004 |
| **优先级** | P0 |
| **预置条件** | 当天压力桶存在时间空隙、无数值桶与运动桶 |
| **输入** | 生成压力分段 |
| **预期结果** | SHALL 只把首尾相接且都有数值的桶连成同一段，空隙或无数值处断开；运动桶标记为运动中；点位于桶中点，数值取显示整数 |
| **测试函数** | stressSegmentsBreakOnGapsAndMarkActivity_TC_TIMELINE_004 |
| **层次** | Swift Testing Core单元 |

### SC-TIMELINE-005 — 曲线断线

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TIMELINE-005 |
| **对应 Spec** | daily-timeline/spec.md → Scenario: SC-TIMELINE-005 |
| **优先级** | P0 |
| **预置条件** | 电量点序列中间有nil |
| **输入** | 生成电量分段 |
| **预期结果** | SHALL 在nil处断开，不插值、不画0；电量当前值不可显示（覆盖不足、过期、校准或缺失）时不输出电量曲线，界面改为显示原因；分析日已结束时标记为非今天，界面显示报告日期 |
| **测试函数** | energySegmentsBreakOnMissingPoints_TC_TIMELINE_005 |
| **层次** | Swift Testing Core单元 |

### SC-SLEEPUI-001 — 阶段时间轴

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SLEEPUI-001 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-SLEEPUI-001 |
| **优先级** | P0 |
| **预置条件** | 主睡眠含清醒、REM、核心、深睡、未细分与unknown段，另有inBed记录 |
| **输入** | 生成SleepBreakdown泳道 |
| **预期结果** | SHALL 按清醒、REM、核心、深睡、未细分、未知顺序输出泳道段，不含inBed；泳道取自完整睡眠分段与主睡眠区间的交集，主睡眠内的清醒与未知段同样显示；不合并不同阶段 |
| **测试函数** | sleepLanesOrderStagesAndExcludeInBed_TC_SLEEPUI_001 |
| **层次** | Swift Testing Core单元 |

### SC-SLEEPUI-002 — 空值不当0

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SLEEPUI-002 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-SLEEPUI-002 |
| **优先级** | P0 |
| **预置条件** | 睡眠有时长但无任何具体阶段，效率与入睡潜伏为nil |
| **输入** | 生成阶段时长、占比与指标 |
| **预期结果** | SHALL 具体阶段时长与占比为nil，未细分可显示；效率与入睡用时为nil；有具体阶段时未出现的具体阶段为0，四项占比和为100% |
| **测试函数** | sleepBreakdownKeepsUnknownStagesEmpty_TC_SLEEPUI_002 |
| **层次** | Swift Testing Core单元 |

### SC-SLEEPUI-003 — 空值不当0

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SLEEPUI-003 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-SLEEPUI-003 |
| **优先级** | P0 |
| **预置条件** | 没有主睡眠但有小睡，或完全无睡眠记录 |
| **输入** | 生成SleepBreakdown |
| **预期结果** | SHALL 不输出泳道；小睡列表照常输出；无记录时总时长为nil；无任何睡眠分段时已记录清醒时长与次数为nil，界面显示“—” |
| **测试函数** | sleepBreakdownWithoutPrimaryKeepsNaps_TC_SLEEPUI_003 |
| **层次** | Swift Testing Core单元 |

### SC-SLEEPUI-004 — 睡眠指标

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SLEEPUI-004 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-SLEEPUI-004 |
| **优先级** | P1 |
| **预置条件** | 报告有效率、入睡潜伏、已记录清醒时长与次数及两段小睡 |
| **输入** | 打开睡眠详情页 |
| **预期结果** | SHALL 显示效率百分比、入睡用时、“已记录清醒”时长与次数、按时间排序的小睡起止与时长；演示模式显示合成标签 |
| **测试函数** | —（模拟器合成演示截图视觉检查，含合成标签） |
| **层次** | 模拟器/人工 |

### SC-TREND-001 — 7日趋势切换

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TREND-001 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-TREND-001 |
| **优先级** | P0 |
| **预置条件** | history缺少某日条目且某日值为nil，分别选择准备度、睡眠、负荷 |
| **输入** | 生成TrendSeries |
| **预期结果** | SHALL 输出以报告日为终点的连续7个日历日，缺失日值为nil；有效天数为非nil个数；睡眠值以小时表示；均值只按有效天计算，有效天数为0时均值为nil；日期按固定分析时区的日历日生成，夏令时切换周仍为7个连续日 |
| **测试函数** | trendSeriesFixesSevenDaysAndValidMean_TC_TREND_001 |
| **层次** | Swift Testing Core单元 |

### SC-TREND-002 — 7日趋势切换

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-TREND-002 |
| **对应 Spec** | sleep-and-trend-detail/spec.md → Scenario: SC-TREND-002 |
| **优先级** | P1 |
| **预置条件** | 首页7日卡片 |
| **输入** | 切换准备度、睡眠、负荷 |
| **预期结果** | SHALL 只为非nil日绘制柱形，页脚显示“有效N/7天”及均值，VoiceOver可读；负荷标为已观测负荷且不显示均值（含未完成与部分观测日） |
| **测试函数** | —（模拟器截图三种切换 + VoiceOver标签静态审阅） |
| **层次** | 模拟器/人工 |

## 测试执行矩阵

| Capability | Core单元 | 引擎集成 | 静态检查 | 模拟器/人工 |
| --- | --- | --- | --- | --- |
| metric-contributions | CONTRIB-001～005 | — | CONTRIB-006 | CONTRIB-006 |
| daily-timeline | TIMELINE-002～005 | TIMELINE-001 | — | 首页两张图截图 |
| sleep-and-trend-detail | SLEEPUI-001～003、TREND-001 | — | TREND-002 VoiceOver标签 | SLEEPUI-004、TREND-002 |

## 回归风险矩阵

| 改动区域 | 风险 | 回归手段 |
| --- | --- | --- |
| HealthEngine写入EnergyReport区间 | 中：误改重放输入或数值 | TIMELINE-001断言数值与改动前一致；12份金例与全部Core测试 |
| EnergyReport Codable新增Optional字段 | 中：旧仓库状态解码失败 | TIMELINE-003旧JSON解码；workspace仓库重开测试 |
| DisplaySnapshot/Watch同步 | 低：本次不改，误触会破坏同步 | 不修改该文件；既有Receiver与快照测试 |
| PhoneDashboardView/MetricDetailView布局 | 中：缺失/演示/过期显示回归 | 模拟器合成演示与空状态截图；MetricExplanation既有测试 |
| 新增SleepDetailView | 低 | 模拟器截图与VoiceOver静态审阅 |

## 建议补充顺序

P0：CONTRIB-001～005、TIMELINE-001～005、SLEEPUI-001～003、TREND-001（Core模型与引擎，按切片先RED后GREEN）。
P1：CONTRIB-006、SLEEPUI-004、TREND-002（界面，Core全绿后以模拟器合成演示验证；真机由用户验收）。
