# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
Core纯模型与真实HealthEngine集成均用合成输入，先RED后GREEN；界面以模拟器合成演示截图与静态检查验证。保持64 Core + 5 workspace与12份金例通过。

## 详细测试案例

### SC-LONG-001 — 35日逐日历史

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-LONG-001 |
| **对应 Spec** | long-trends/spec.md → Scenario: SC-LONG-001 |
| **优先级** | P0 |
| **预置条件** | 合成记录覆盖23个分析日（少于35日），部分日缺夜间HRV或静息心率，且白天另有HRV |
| **输入** | HealthEngine评估当日报告 |
| **预期结果** | SHALL 输出以今天为终点的35个分析日history，逐日含nightHRV与restingHeartRate，缺输入的日为nil；夜间HRV只取主睡眠内样本且至少2条；准备度、压力、电量数值与改动前一致（电量点校验和由TC-TIMELINE-001覆盖） |
| **测试函数** | engineExtendsHistoryWithNightInputs_TC_LONG_001 / nightHRVIgnoresDaytimeAndNeedsTwoSamples_TC_LONG_001 |
| **层次** | Swift Testing真实HealthEngine集成 |

### SC-LONG-002 — 个人基线区间

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-LONG-002 |
| **对应 Spec** | long-trends/spec.md → Scenario: SC-LONG-002 |
| **优先级** | P0 |
| **预置条件** | 今天准备度为夜间模式，前60个分析日内今天主睡眠来源的有效夜间成对日分别为20、17（另有其他来源夜晚）与13；另一例今天无主睡眠 |
| **输入** | 计算personalRanges |
| **预期结果** | SHALL 夜间模式且至少14日时输出HRV区间exp(中位数±0.5尺度)与静息心率区间中位数±0.5尺度及有效日数，与今天准备度的baselineDays和基线中心一致；不足14日或今天为日间回退时为nil；只计今天主睡眠来源的夜晚，不混合来源；区间边缘对应准备度z=±0.5；无效配对不计入，校准期baselineDays不变 |
| **测试函数** | personalRangesMatchReadinessBaseline_TC_LONG_002 / personalRangesFollowSleepSourceAndNightMode_TC_LONG_002 / personalRangesShareReadinessValidation_TC_LONG_002 |
| **层次** | Swift Testing Core单元 |

### SC-LONG-003 — 7/30日趋势

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-LONG-003 |
| **对应 Spec** | long-trends/spec.md → Scenario: SC-LONG-003 |
| **优先级** | P0 |
| **预置条件** | 35日history中有缺日与nil值 |
| **输入** | 按30日生成准备度、夜间HRV、静息心率序列 |
| **预期结果** | SHALL 输出以报告日为终点的30个分析日，缺失为nil，有效天数与均值只计非nil；7日行为与上一轮一致 |
| **测试函数** | trendSeriesSupportsThirtyDaysAndNightInputs_TC_LONG_003 / thirtyDayReadinessAndLegacySevenDayHistory_TC_LONG_003 |
| **层次** | Swift Testing Core单元 |

### SC-LONG-004 — 7/30日趋势

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-LONG-004 |
| **对应 Spec** | long-trends/spec.md → Scenario: SC-LONG-004 |
| **优先级** | P0 |
| **预置条件** | 旧缓存JSON的DayOverview与HealthReport缺少新字段，或history只有7日 |
| **输入** | 解码 |
| **预期结果** | SHALL 解码成功，新字段为nil；7日旧history仍生成30个日期位置，近7日回顾此前28日为空 |
| **测试函数** | legacyHistoryDecodesWithoutNightInputs_TC_LONG_004 |
| **层次** | Swift Testing Core单元 |

### SC-LONG-005 — 7/30日趋势

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-LONG-005 |
| **对应 Spec** | long-trends/spec.md → Scenario: SC-LONG-005 |
| **优先级** | P1 |
| **预置条件** | 首页趋势卡片 |
| **输入** | 切换7/30日与五个指标 |
| **预期结果** | SHALL 只为非nil日绘制，HRV/静息心率在有个人基线区间时显示区间带并注明来源与有效夜晚数，无区间时说明原因，VoiceOver可读 |
| **测试函数** | —（模拟器合成演示截图与静态检查） |
| **层次** | 模拟器/人工 |

### SC-WEEK-001 — 近7日与此前28日对比

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WEEK-001 |
| **对应 Spec** | weekly-review/spec.md → Scenario: SC-WEEK-001 |
| **优先级** | P0 |
| **预置条件** | 35日history，近7日有效日为3、2与4，此前28日有效日为10、9与12，含真实0与窗口外行，纽约夏令时周 |
| **输入** | 生成周回顾 |
| **预期结果** | SHALL 达到门槛时输出两段均值、有效天数与差值（近7日−此前28日），未达门槛的一段均值为nil且不给差值；真实0计入均值，负荷不参与，窗口外行不计；差值文本按显示精度先取整再相减，零不带符号 |
| **测试函数** | weeklyReviewComparesWithThresholds_TC_WEEK_001 / weeklyReviewEdgesAndShownDifference_TC_WEEK_001 |
| **层次** | Swift Testing Core单元 |

### SC-WEEK-002 — 近7日与此前28日对比

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WEEK-002 |
| **对应 Spec** | weekly-review/spec.md → Scenario: SC-WEEK-002 |
| **优先级** | P1 |
| **预置条件** | 首页近7日回顾卡片 |
| **输入** | 查看 |
| **预期结果** | SHALL 显示四项的近7日与此前28日均值、有效天数和差值，记录不足明确写出，不含原因或建议 |
| **测试函数** | —（模拟器合成演示截图与静态检查） |
| **层次** | 模拟器/人工 |

## 测试执行矩阵

| 场景 | Capability | 层次 | 优先级 |
| --- | --- | --- | --- |
| LONG-001 | long-trends | Swift Testing真实HealthEngine集成 | P0 |
| LONG-002 | long-trends | Swift Testing Core单元 | P0 |
| LONG-003 | long-trends | Swift Testing Core单元 | P0 |
| LONG-004 | long-trends | Swift Testing Core单元 | P0 |
| LONG-005 | long-trends | 模拟器/人工 | P1 |
| WEEK-001 | weekly-review | Swift Testing Core单元 | P0 |
| WEEK-002 | weekly-review | 模拟器/人工 | P1 |

## 回归风险矩阵

| 改动区域 | 风险 | 回归手段 |
| --- | --- | --- |
| HealthEngine history长度与DayOverview字段 | 中：误改评分输入 | LONG-001数值与校验和对照；12份金例 |
| HealthReport Codable新增Optional | 中：旧缓存解码 | LONG-004旧JSON解码；仓库重开测试 |
| 首页趋势卡片 | 中：缺失显示为0 | 截图与TrendSeries单测 |

## 建议补充顺序

P0：LONG-001～004、WEEK-001；P1：LONG-005、WEEK-002（模拟器截图）。
