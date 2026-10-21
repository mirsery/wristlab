# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
Core纯模型用合成MoodEntry与压力桶，先RED后GREEN；HealthKit读取为平台适配器，以编译与真机验收为证据；界面用模拟器合成截图。

## 详细测试案例

### SC-MOOD-001 — 中文映射

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-MOOD-001 |
| **对应 Spec** | mood-records/spec.md → Scenario: SC-MOOD-001 |
| **优先级** | P0 |
| **预置条件** | 分类1–7、标签1–38、关联项1–18及越界值 |
| **输入** | 取中文名 |
| **预期结果** | SHALL 返回固定中文名，越界返回“未知”且不崩溃 |
| **测试函数** | moodNamesCoverAllKnownValues_TC_MOOD_001 / moodNameTablesFollowSDKOrder_TC_MOOD_001 |
| **层次** | Swift Testing Core单元 |

### SC-MOOD-002 — 压力配对

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-MOOD-002 |
| **对应 Spec** | mood-records/spec.md → Scenario: SC-MOOD-002 |
| **优先级** | P0 |
| **预置条件** | 即时情绪记录时刻落在有值压力桶内、在桶结束后0/15/16分钟、只有无值桶、之前2分钟只有之后的桶、运动桶；每日心情在非UTC分析日跨午夜 |
| **输入** | 配对压力 |
| **预期结果** | SHALL 取包含该时刻的有值桶，否则其前15分钟内结束的最近有值桶，16分钟、只有无值桶或只有之后的桶时为空；运动桶标注运动中；每日心情取当天半开分析日内有值桶中位数（偶数个取均值后四舍五入），无值为空；报告stressTimeline覆盖D-6前15分钟至asOf，当天以外的桶不进入一天的节奏；配对结果给出压力显示值与002分段 |
| **测试函数** | moodPairsWithNearbyStressOnly_TC_MOOD_002 / reportStressTimelineCoversSevenDays_TC_MOOD_002 / moodPairingEdgesAndLocalDays_TC_MOOD_002 / stressTimelineSpansSevenAnalysisDays_TC_MOOD_002 |
| **层次** | Swift Testing Core单元 |

### SC-MOOD-003 — 最近记录与时间线标记

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-MOOD-003 |
| **对应 Spec** | mood-records/spec.md → Scenario: SC-MOOD-003 |
| **优先级** | P0 |
| **预置条件** | 跨8天、含未来时间、窗口边界与重复ID的合成记录，非UTC与夏令时分析时区，含运动中、当天进行中与晚于报告的记录 |
| **输入** | 生成最近7天列表与当天时间线标记 |
| **预期结果** | SHALL 列表为最近7个分析日内、当前时刻（含）之前的记录按时间倒序去重；时间线只含当天即时情绪；行标出运动中、当天截至目前与晚于报告 |
| **测试函数** | recentMoodsUseAnalysisDaysAndDeduplicate_TC_MOOD_003 / recentMoodWindowEdgesAndDST_TC_MOOD_003 / moodRowsFlagActivityTodayAndAfterReport_TC_MOOD_003 |
| **层次** | Swift Testing Core单元 |

### SC-MOOD-004 — 心情卡片与压力图标记

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-MOOD-004 |
| **对应 Spec** | mood-records/spec.md → Scenario: SC-MOOD-004 |
| **优先级** | P1 |
| **预置条件** | 首页心情卡片与压力图 |
| **输入** | 未连接、已连接无记录、有记录三种状态 |
| **预期结果** | SHALL 分别显示连接按钮与说明、无记录说明、记录列表与同时段生理压力；压力图标出当天记录时刻并有图例；声明自报与非因果；演示模式标记合成 |
| **测试函数** | —（有记录态：模拟器合成截图；未连接/无记录态与iOS 17隐藏：静态检查，真机验收） |
| **层次** | 模拟器/人工 |

## 测试执行矩阵

| 场景 | Capability | 层次 | 优先级 |
| --- | --- | --- | --- |
| MOOD-001 | mood-records | Swift Testing Core单元 | P0 |
| MOOD-002 | mood-records | Swift Testing Core单元 | P0 |
| MOOD-003 | mood-records | Swift Testing Core单元 | P0 |
| MOOD-004 | mood-records | 模拟器/人工 | P1 |

## 回归风险矩阵

| 改动区域 | 风险 | 回归手段 |
| --- | --- | --- |
| HealthKitReader新增查询 | 中：误改既有锚点或授权 | 心情不进types列表；单独授权；构建与真机验收 |
| 首页压力图 | 低 | 截图 |

## 建议补充顺序

P0：MOOD-001～003；P1：MOOD-004。
