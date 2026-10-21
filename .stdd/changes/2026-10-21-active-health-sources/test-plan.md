# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
纯Foundation公共API与完整引擎/仓库集成，全部合成输入；先用最小复现RED，再用真实调用链回归GREEN。

## 详细测试案例

### SC-SOURCE-001 — 历史失活来源

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-001 |
| **对应 Spec** | SC-SOURCE-001 |
| **预置条件** | 旧优先来源仅在60日计算窗口外有记录，另一个来源窗口内有有效记录 |
| **输入** | 自动选源并评估报告 |
| **预期结果** | SHALL 选择窗口内有效来源，不让历史来源遮挡当前压力桶 |
| **测试函数** | activeSourceRestoresCurrentStressAndEnergy_TC_SOURCE_001 |
| **层次** | Swift Testing Core单元/集成 |

### SC-SOURCE-002 — 保留既有优先级

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-002 |
| **对应 Spec** | SC-SOURCE-002 |
| **预置条件** | 多个来源均在窗口内有有效记录 |
| **输入** | 自动选源 |
| **预期结果** | SHALL 继续按Watch、第三方、iPhone及group顺序固定单组，不按每桶填补缺口 |
| **测试函数** | activeSourceRetainsRankAndSingleGroup_TC_SOURCE_002 |
| **层次** | Swift Testing Core单元/集成 |

### SC-SOURCE-003 — 明确偏好优先

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-003 |
| **对应 Spec** | SC-SOURCE-003 |
| **预置条件** | 用户明确指定的来源仍有保留记录，即使其不在当前窗口 |
| **输入** | 选择HR、RHR或HRV来源 |
| **预期结果** | SHALL 尊重明确偏好，不静默改用户配置；不同类型独立选择 |
| **测试函数** | activeSourceRespectsPreferencesAndTypeIsolation_TC_SOURCE_003 |
| **层次** | Swift Testing Core单元/集成 |

### SC-SOURCE-004 — 边界及完整历史

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-004 |
| **对应 Spec** | SC-SOURCE-004 |
| **预置条件** | 候选来源有窗口边界、窗口外和未来样本 |
| **输入** | 构建候选组及输出选定组记录 |
| **预期结果** | SHALL 用有效样本end在起点至asOf闭区间判定候选；排除未来；返回选定组全部保留有效历史 |
| **测试函数** | activeSourceWindowBoundsAndValidity_TC_SOURCE_004 / activeSourceEngineUsesCalendarWindowAcrossDST_TC_SOURCE_004 |
| **层次** | Swift Testing Core单元/集成 |

### SC-SOURCE-005 — 确实缺失与校准

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-005 |
| **对应 Spec** | SC-SOURCE-005 |
| **预置条件** | 没有自动候选或选中当前HR但无14日有效基线 |
| **输入** | 运行评分 |
| **预期结果** | SHALL 分别保持必要输入缺失或校准，不生成默认数值 |
| **测试函数** | activeSourceKeepsMissingAndCalibrationHonest_TC_SOURCE_005 |
| **层次** | Swift Testing Core单元/集成 |

### SC-SOURCE-006 — 来源切换一致重建

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-SOURCE-006 |
| **对应 Spec** | SC-SOURCE-006 |
| **预置条件** | 持久化报告使用历史失活来源，刷新后选择有效来源 |
| **输入** | 仓库apply并发布快照 |
| **预期结果** | SHALL 重算报告与电量，sourceSignature变化时推进epoch，并让快照指标与报告一致 |
| **测试函数** | activeSourceRebuildAdvancesEpochAndSnapshot_TC_SOURCE_006 |
| **层次** | Swift Testing Core单元/集成 |

## 执行矩阵
6个场景由7个Core测试函数覆盖；scripts/check.sh覆盖既有规格、金例和工作区，build-apple.sh覆盖双端/组件；真机刷新、来源资格状态与安装另行记录，不导出数值。

## 回归风险
HR/RHR/HRV候选资格中风险；显式偏好、闭区间边界、DST与epoch中风险，睡眠和评分公式不变但全量回归。

## 顺序
P0：001/004/005/006；P1：002/003。Core全绿后构建与真机验证。

## 用户追加：缺失原因说明

### SC-EXPLAIN-001 — 夜间基线不足

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-EXPLAIN-001 |
| **预置条件** | 已有主睡眠及配对夜间输入，但历史不足14个有效日 |
| **输入** | 构建无seed电量估算 |
| **预期结果** | SHALL 使用calibrating、baselineNotReady及真实baselineDays，不错误归因缺少睡眠 |
| **测试函数** | energyInsufficientNightBaselineExplainsProgress |
| **层次** | Core真实引擎/展示模型/快照往返；SwiftUI布局以合成模拟器另验 |

### SC-EXPLAIN-002 — 必要夜间输入缺失

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-EXPLAIN-002 |
| **预置条件** | 主睡眠、夜间HRV或对应RHR缺少一种 |
| **输入** | 构建无seed电量估算 |
| **预期结果** | SHALL 分别给出必要输入原因，不造分数或放松门槛 |
| **测试函数** | energyDistinguishesMissingNightInputs / energyLatestNightMissingInputOverridesEarlierCalibration |
| **层次** | Core真实引擎/展示模型/快照往返；SwiftUI布局以合成模拟器另验 |

### SC-EXPLAIN-003 — 双端可见且同一解释

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-EXPLAIN-003 |
| **预置条件** | 同步包含校准或缺失原因的指标 |
| **输入** | 手机/Watch首页及详情展示 |
| **预期结果** | SHALL 首页直接说明原因与X/14进度，详情提供操作建议；同步沿用原schema与理由字段 |
| **测试函数** | explanationProgressSurvivesSnapshotRoundTripAndWatchMapping |
| **层次** | Core真实引擎/展示模型/快照往返；SwiftUI布局以合成模拟器另验 |

### SC-EXPLAIN-004 — 状态优先与未知回退

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-EXPLAIN-004 |
| **预置条件** | 真实零、过期、低覆盖、未知原因或无快照 |
| **输入** | 生成说明及展示值 |
| **预期结果** | SHALL 保留真实0、过期隐藏旧值并说明刷新、覆盖不足说明门槛，未知原因中性回退且不推断拒绝权限 |
| **测试函数** | explanationSeparatesMissingStaleCoverageAndRealZero / explanationMissingExpiredOrFutureInputsMatchWatchPriority |
| **层次** | Core真实引擎/展示模型/快照往返；SwiftUI布局以合成模拟器另验 |
