# 运动计划与减重目标 — 验证报告

## 表单与明细体验优化
用户要求“继续优化”，本轮增加保存前具体错误/禁用无效提交、进入表单清旧提示、保存中提示、数字键盘完成收起、稳定排序及每次10条明细。全程保持kg，不改模型或存储。
work/planning-ux-check.log：110个Core及5个workspace测试通过；work/planning-ux-apple.log两scheme构建和Watch/phone Widget注册通过，此前iPhone注册宿主启动失败本次未复现，不将旧失败证据删除。最终命名调整由work/planning-ux-device.log真机目标BUILD SUCCEEDED验证。git diff --check及project-check通过。
这些是编译/回归证据，新表单与键盘、分页的实际手机交互仍待用户验收；未代批Gate3。

## 仅公斤显示修正
用户要求“去除 lb 磅这个显示”，三处体重页面改为固定kg并移除切换。work/kg-only-check.log的110个Core加5个workspace测试通过；work/kg-only-device.log真机包BUILD SUCCEEDED，安装到mi成功（序号2348），包内无Watch。work/kg-only-apple.log两scheme构建通过，但iPhone Widget注册宿主启动失败（NSPOSIXErrorDomain code3，未返回进程句柄），保留诊断，不声称整条Apple脚本全绿；此项仍需后续验证。

状态：实现与自动检查完成；真机安装、UI交互待验收，Gate3未批准。

## 手机安装更新
用户随后回复“连接完毕”。devicectl确认mi connected，使用已成功通用iOS构建的phone-only包完成安装，bundleID com.mirsery.wristlab，databaseSequenceNumber 2340。包内无Watch目录，实体手表未安装。
此次仅安装activity-weight-plan已实现版本，不包含仍在Gate2设计确认阶段的adaptive-movement自动周计划。实际交互与Gate3仍需用户验收。

## 用户调整与补充本地验证
用户明确“先做功能，等会我回去再测试手机”，真机安装和体验验收延期，不继续要求连接手机。
补充3个回归：暂停目标仍可记录且目标历史保留；健康apply/configure/派生清除完整保留手动数据；建议优先遵守暂停/休息/已完成；合成计划不会进入发布快照。
最新work/planning-local-check.log：110个Core加5个workspace测试通过，共115项；PlanningTests新增累计16个函数。上述是规则和数据证据，不代表手机UI通过。

## 行为及规格
本轮P-013–P-016、PLAN-001/002/003/004、WEIGHT-001/002/003/004。
新增本地周计划、显式完成/替换/休息及撤销，状态解释与可选轻量安排；kg/lb手动体重和减重目标、目标历史、日值/周均和断线；旧缓存兼容、revision保存和清除策略。
phone-tabs为此前未提交改动，保留而不混算为本轮功能。无新健康读取权限，不写健康/Watch/Widget，不新增依赖。

## 自动检查证据
- RED：work/planning-red.log，PlanningState/MovementPlan不存在；同时发现测试误写只读value，已改rawValue，未把该测试错误当产品失败。
- GREEN：work/planning-release-check.log：107个Core测试和5个workspace测试通过，共112个；PlanningTests.swift新增13个函数，含32.49/32.5/80参数化。
- 平台：work/planning-release-apple.log，iOS与watchOS模拟器BUILD SUCCEEDED、Watch四配置及phone配置REGISTRATION PASS。
- git diff --check通过，STDD validate及project-check另运行。
- 真机指定目标构建：work/planning-device-final.log显示找不到目标；devicectl确认mi unavailable，未安装本轮新功能，实体手表未安装。通用设备包构建见work/planning-device-generic.log，编译不能当安装成功。
- stdd ci check-failures退出1：5项通过/4项跳过，TC源码映射0/8；不能据此宣称全流程门禁全绿。

## 测试与场景映射
| TC | 单元/集成证据 | 未验证 |
| --- | --- | --- |
| PLAN-001 | planningEditsPreservePastAndCompletedSnapshots、planningRejectsCorruptHistoryAndProcessedLightReplacement | 配置表单实际操作 |
| PLAN-002 | planningLowReadinessOnlyOffersPresetAlternative、planningUsesDisplayedReadinessBoundary | 所有状态的真实展示/跨午夜交互 |
| PLAN-003 | planningExecutionPreservesSnapshotAndIsIdempotent、planningEditsPreservePastAndCompletedSnapshots | 完成/替换/休息/撤销交互及周回顾 |
| WEIGHT-001 | weightValidationAndConversion、weightGoalRejectsInvalidDatesAndPositiveValues | kg/lb表单实际录入 |
| WEIGHT-002 | weightWeeklyMeanCountsDaysAndPreservesGaps、weightWeekUsesAnalysisTimeZoneAndDST、weightDeletionAndSameTimestampTieAreDeterministic、weightTrendSplitsRealGapsAndNeedsBothWeekMeans | 图表/删改交互 |
| WEIGHT-003 | 模型与校验路径、手动记录独立于目标暂停；静态评审 | 暂停/调整/达到提示完整交互 |
| WEIGHT-004 | planningMigrationAndClearPreserveManualState、planningOldCacheMigratesAndFailedCommitKeepsState | iOS文件保护、界面保存失败/清除竞争交互 |
| PLAN-004 | 三路静态评审、双平台编译，expectedDemo保护 | 五Tab、空态、演示切换、大字体与VoiceOver |

单元测试覆盖7个TC的部分规则，WEIGHT-003和PLAN-004尚无完整自动化行为验证；8个完整TC没有端到端验收，不计为8/8。
写失败注入方法为移除原文件并建立同名目录，仅证明仓库内存及revision不前进，不证明被测试人为删除的原文件恢复。
模拟器布局/交互尚未取得有效证据，不用构建代替渲染或读屏。

## 三路技术评审
代码、测试、规格评审均完成；复查未发现需先修的确定阻断。已修：await后generation复核、操作捕获显示计划日及来源、历史快照校验和已处理轻量覆盖保护、目标lb输入、趋势周执行回顾、具体降级原因。
规则版本activity-plan-v1，未修改评分公式。实际生活或医学效果未验证。

## 后续验收
连接并解锁mi后安装仅手机包；用户实际检查计划设置、完成/替换/休息/撤销、kg/lb记录和删改、目标暂停、演示退出、清除和大字体读屏。
无用户确认不批准Gate3、不归档，不提交或推送。
