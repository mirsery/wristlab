# 自动周计划与每日完成度 — 验证报告

状态：Build实现与自动检查，Gate3待实际用户确认；不将九个TC全部标为完成。

## 行为与覆盖
- P-017–P-019：偏好向导、可编辑预览、独立采纳版本、未来生效与历史模式；完整上周反馈生成下一周草案，需确认，不补课。
- MATCH：复用只读workout，duration/暂停事件生成活跃区间；同类型去重并集、实际日裁剪、按秒达标；缺字段不猜、重读入口、来源/排除原因和修订说明。人工状态独立。
- 保留五Tab、睡眠顶部修复及kg-only；不改变评分公式，不把目标公斤或期限换算为处方。无新依赖，计划不进入Watch/Widget。

## 实际自动证据
- RED：work/automatic-red.log（缺领域类型）；测试代码自身的try问题另行修正，不作为产品失败。
- work/automatic-final-check.log：125个Core＋5个workspace测试通过，共130；新增15个函数，参数化共18个案例。
- work/automatic-final-apple.log：iOS/watchOS模拟器两项BUILD SUCCEEDED，Watch/phone Widget两项REGISTRATION PASS；实体手表不安装。
- git diff --check、stdd --project-check通过。首次未指定DEVELOPER_DIR时出现SDK/编译器不匹配，改用完整Xcode后通过，没有修改系统工具链。

## TC映射与缺口
| TC | 已执行证据 | 仍需验证 |
| --- | --- | --- |
| AUTO-001 | automaticWeekRespectsCapacityAndIsDeterministic、automaticWeekStartsTomorrowAndDeadlineDoesNotIncreaseDose | 向导交互 |
| AUTO-002 | automaticAcceptanceKeepsCompletedAndManualPlan、automaticManualModeSwitchKeepsHistoricalSchedule、automaticRepeatedAcceptanceUsesLatestRevision | 取消/编辑/采纳真实交互 |
| AUTO-003 | automaticNextWeekNeedsEvidenceAndAcceptance | 全部反馈边界组合及周回顾UI |
| AUTO-004 | 日期约束模型测试及Apple编译 | 目标到期/暂停/续期和五Tab实际体验 |
| MATCH-001 | workoutEvidenceExcludesPausesAndRejectsAmbiguity、workoutPauseValidationRejectsMalformedEvents、workoutLegacyFieldsRemainMissingAndCanBeRebuilt | 真实HK事件转换/旧缓存重读 |
| MATCH-002 | workoutCompletionUnionsOverlapsAndClipsMidnight、workoutCompletionClipsActualDSTDay | 自动匹配的异源优先级集成组合 |
| MATCH-003 | workoutCompletionUsesSecondsAndNeverInventsMissing、workoutToleranceNeverCompletesBeforeDurationTarget | 手机展示 |
| MATCH-004 | workoutRevisionRecomputesAfterRevisionAndDeletion；无写入的纯投影 | 人工完成/休息与删除组合UI、跨重启修订提示（仅通用解释，不保存前次提示） |
| MATCH-005 | automaticFieldsAreOptionalForPreviousPlanningCache、采纳JSON往返及既有存储事务回归 | 嵌套自动状态的仓库重开/清除组合和来源切换UI |

## 评审与边界
三路只读评审均未发现剩余确定阻断；发现的A→B→A版本回退已修复并回归。补充目标起始约束、到期回顾、不可计入记录详情及修订解释。专门的减少提示仅在页面存活时比较；所有打开均显示重算规则，不伪称跨重启记忆。
无法取得模拟器可读截图或CUA交互证据，编译不是UI验收。真实健康数据和手机操作需用户验收；不打印真实记录、不代批Gate3。

## 手机安装
work/automatic-phone-build.log：phone-only真机包BUILD SUCCEEDED，包内无Watch目录；work/automatic-phone-install.log：mi安装成功，bundle com.mirsery.wristlab，databaseSequenceNumber 2372。work/automatic-phone-launch.log确认Launched application。启动成功不等于页面交互或真实健康完成度已经验收；实体手表未安装。

## 用户“继续”后的可靠性补验

仅新增测试和验证文档，没有更改生产代码、界面或安装包；复用本change已确认的MATCH-002/004/005和AUTO-003范围，不代批Gate3。

- automaticRepositoryReopensAndClearProtectsAgainstStaleWrites：嵌套自动计划真实落盘重开；刷新、配置、派生清除保留；停止读取清除后重开为空，旧revision的savePlanning和apply均被拒绝。
- automaticWorkoutRefreshPreservesExplicitStatus：完成/休息参数化，真实仓库新增运动达标与删除后unknown，人工条目和全部规划不变。
- automaticNextWeekHonorsConfirmationThreshold：四反馈分别验证4/5=80%、3/5不足和确认不完整，仅满足门槛且轻松才加量。
- automaticCompletionUsesPreferredDuplicateSourceAndKeepsOtherTypeSeparate：同类型同起止、不同活跃分钟的异源记录按偏好选择；切换来源会重算，其他类型只进说明。

work/automatic-continuation-check.log：129个Core＋5个workspace测试通过，共134。累计新增19函数；git diff --check通过。首轮新增测试的require宏缺内层try已修正，是测试编译问题，不虚记为产品RED。未改应用目标，本轮不重复Apple构建/真机安装；上一节安装仅代表上一轮包。

三路只读复核无确定阻断。评审指出缺少清除后晚到apply验证，本轮随后补齐并全量重跑通过；这仍是确定性revision时序，不等于真实并发调度。未覆盖：Dashboard演示切换/generation交互、真实HK事件、UI反馈计数汇总、同ID修改及重复刷新专项、自动调整的150/5分钟全部边界。

work/automatic-continuation-stdd.log：ci check-failures仍报告TC源码映射0/9（扫描器识别范围不含当前Swift测试），另4项跳过，不能称STDD全门禁通过；本报告的函数映射是人工核对，不伪造coverage。项目结构检查与自动测试通过不替代UI/真机验收。
