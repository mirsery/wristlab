# Watch日常关怀版验证报告

后续真机已尝试，2401安装成功但用户确认Watch闪退、手机读取未通过；见[真机记录](device-validation.md)。下文是Gate 3时的代码/模拟器阶段报告，不代表后续真机通过。

2026-10-24；当前未提交工作区，thorough/full_auto。Gate 1/2有真实用户确认；用户预授权仅本地编辑/测试/模拟器，未操作真机、未提交推送、未启用iCloud。报告展示后用户回复“确认开始完成吧”，Gate 3已按保留已披露平台缺口的边界记录，不把这些缺口变成通过。

## 一、结果与边界

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| scripts/check.sh | 退出0；196 Core + 35 workspace = 231项通过 | work/watch-care-check-pass.log |
| 归档后再次回归 | 退出0；196 Core + 35 workspace = 231项通过 | work/watch-care-delivery-check.log |
| 新增测试 | 21函数：Core11、workspace10；全部通过 | 同上；基线185+25=210 |
| scripts/build-apple.sh | 退出0；iOS和watchOS模拟器BUILD SUCCEEDED | work/watch-care-build-pass.log |
| 生产组件注册 | Watch energy/readiness/stress/overview/activity及iPhone phone全部运行PASS | 同上；不是全family外观或系统表盘安装验证 |
| 规格/本地链接/Diff | validate、project-check、check_specs.py、git diff --check通过 | 实际命令；project-check保留另一综合周报AND累计警告 |
| 行/分支覆盖率 | SKIPPED：项目未配置，不安装新覆盖工具、不伪造百分比 | quality.yaml coverage.enabled=false |
| Python-only TC扫描 | 仍报0/15；不是Swift实际测试结论 | work/watch-care-ci-failures-final.log；上游ci.py仅扫描test_*.py |
| 完整UI/真机验收 | 未完成，不能声称15场景全通过 | 下述已观察范围与待验项 |

三阶段切片：S1模型9项新增测试关联8个TC，S2存储/协调10项关联5个TC，S3路由/时间线2项关联2个TC。15/15指代码测试引用，不是行覆盖或全平台场景验收。S1/S2自动验证完成；S3实现和自动检查完成，但交互验证部分缺失，状态不标全验收完成。

## 二、行为与TC追溯

| TC | 新测试主要入口（Swift函数名） | 已证实与限制 |
| --- | --- | --- |
| WCP-001 | iconBoundaries_TC_WCP_001；actualPresentationBoundaries_TC_WCP_001_002 | 图标/分段、准备度边界、真实0电量；视觉与朗读待平台 |
| WCP-002 | pressureContextAndExpiry_TC_WCP_002；actualPresentationBoundaries_TC_WCP_001_002 | activity/HR-only、900秒边界/过期/未来；原13/14日由原业务回归保护 |
| WCP-003 | reportProjectionProvenanceAndGaps_TC_WCP_003 | 显式4桶有效/缺失/运动/partial，来源序列隔离、超限拒绝；原生完整图表交互待验 |
| WCP-004 | pageAndActivityRoutes_TC_WCP_004_005 | 三页/路由真实模型；已观察原生首屏，Crown/辅助字体/VoiceOver未验 |
| WCP-005 | pageAndActivityRoutes_TC_WCP_004_005；activityTimelineContainsMidnight_TC_WCP_005 | 新旧URL、系统午夜entry、生产kind注册；各family/隐私遮盖外观待验 |
| WDA-001 | explicitActivityAndStopLateRead_TC_WDA_001_005 | 主动前0授权/读取，主动后读取；实际HealthKit权限与空返回待验 |
| WDA-002 | nilAndZeroSteps_TC_WDA_002 | 真0/未知/非法/重复日期/未来不同；HK累计统计adapter由本地SDK编译和代码核查保护 |
| WDA-003 | ringGoalsAndPaused_TC_WDA_003 | 目标未知/非正/超额及暂停；真实Move模式/目标/暂停返回待验 |
| WDA-004 | dateAndStaleness_TC_WDA_004；lateDayAndZoneChangeNeverPublish_TC_WDA_004 | 25h DST、60min/非当日/异时区、跨日换区晚回拒绝；实际系统切区待验 |
| WDA-005 | partialFailurePreservesOriginalTimestamp_TC_WDA_005；stopProjectionRecoveryClearsError_TC_WDA_005；explicitActivityAndStopLateRead_TC_WDA_001_005 | 分项双向失败保留原值与旧时间、合法晚回999步、busy及错误恢复 |
| WCS-001 | moodCapturedDay_TC_WCS_001；moodPrivateAndDayGuard_TC_WCS_002 | 五种心情、私有新增/改/删；不进评分，真实表单交互待验 |
| WCS-002 | failedPrivateWritePreservesFileAndMood_TC_WCS_002；moodPrivateAndDayGuard_TC_WCS_002 | 实际writer失败/重开/损坏保留、跨日及演示旧generation拒绝 |
| WCS-003 | caringDoesNotDiagnose_TC_WCS_003 | 无效优先、自报接纳优先于身体估算、偏高可选停顿、真实成就和中性文案；收起交互待验 |
| WCS-004 | careProjectionIsAtomicBoundedAndMoodFree_TC_WCS_004；projectionRetry_TC_WCS_004；sourceSwitchKeepsConcurrentActivity_TC_WCS_004 | 旧schema、无mood、实际共享写失败、合法JSON40KB边界、恢复与来源切换；竞争测试未穷举调度 |
| WCS-005 | careClearFailureAndRestartKeepBarrier_TC_WCS_005；实际展示store停止标记重开测试 | phone clear保持local、清理失败持续停止、恢复无自动读取；原晚回/停止标记失败测试一并回归 |

代码位置：Core WatchCare.swift/WatchDisplay.swift、Apps/WatchSupport/WatchCareModel.swift及WatchReportModel.swift、Apps/Storage两类store、Watch DailyActivityReader/WatchCareViews/Runtime/App、生产Widget与Shared Guide。边界未挪入Core的Apple API或View直接查询。

## 三、RED → GREEN与审查

- S1新增模型前RED，7个初始领域测试GREEN；随后补足生产展示边界与趋势来源/缺口。
- S2新增store/model前RED；初次投影重试测试发现读取前发布nil阻断首次连接，修复后GREEN。
- 第二阶段回归真实捕获两缺陷：停止后投影恢复遗留notice；select在await前捕获旧包覆盖并发活动。work/watch-care-review-red-retry.log为2失败/7测试，修后work/watch-care-review-green.log为7通过。
- S3缺页面/午夜timeline类型时编译RED，新增实现后9项Core GREEN，最终完整Core196项GREEN。
- 代码/规格/测试三路只读审查并复核；修复静态75%电量、中性心情图标、Guide旧数字/来源说明、七日日期域、HR-only卡片旁注、partial虚线及无障碍质量。修复无效断言：非法晚回夹具、可选continuation、空循环缺口和非法JSON容量样例。最终三路无剩余确定阻断。
- 并发测试用Task调度，原实现实际RED复现，但没有可控repository屏障，因此不声称覆盖全部交错。修复另有await后读取最新状态的代码审查依据。
- Apple初次编译发现表单catch的error遮蔽，改self.error；下一次探针提取发现@main需独立一行，已修。随后iPhone探针输出PASS却simctl无进程句柄，开发宿主延迟2秒退出后完整构建/注册退出0；未吞失败。
- 一次平台命令因自动审批服务额度不足未执行；用户“继续”后重试实际执行。没有绕过审批或把未执行命令列为通过。

## 四、原生UI证据

在46mm Watch模拟器运行真实SwiftUI `--demo`，分别以`--demo-page=care/activity/state`选页。已观察关怀文字、图标压力卡、活动事实/圆环及更多按钮，work/watch-care-native-{home,activity,state}.png；顶部按钮初次同色后已修为深色省略号。截图均为合成输入，不含真实健康记录，且只证明所见首屏，不能证明滑动/VoiceOver。

初次活动截图是黑首帧或表盘；同时运行的Widget探针会接管同一模拟器前台。未据此诊断业务崩溃。注册结束后单独启动活动页，取得真实活动画面与存活进程，排除该次干扰。最终40mm检查见work/watch-care-native-small-activity.png：真实合成活动首屏可读、文字自然换行、步数可见；圆环位于下方，未声称已操作滚动。该截图为最终构建，不是概念图；未观察到的部分不计通过。

CUA未提供可控制的Simulator应用，不能完成真实点击/滚动/Crown。浏览器概念图不计原生验收。以下仍未执行：表单取消/收起等完整原生交互、最大辅助字体/VoiceOver、单色/低亮度/隐私遮盖、五种组件各family与冷/热点击。没有编造成功截图或操作结果。

## 五、失败模式、调整与最终门

14类实际核查及逐项SKIPPED见failure-modes.md；本地新增EXP-20261024-011，复用EXP008，不上传经验或更新全局记忆。非安全实现细化2项见design-adjustments.yaml：活动查询超时取消；开发探针启动/退出修正。未改业务公式或新增隐私权限。

CLI确定性结果仍有6通过/3跳过/1错误（Python-only TC扫描）；canonical旧路径/能力提取与无coverage.json分别人工说明。未修改上游来制造全绿。项目主门禁check.sh/build-apple.sh和diff均通过，但流程辅助工具和全UI未全绿，必须保留这个差异。

真机健康授权、系统汇总/暂停、完全断连、系统表盘、锁屏文件保护全部未测，本轮没有安装到手机/手表。iCloud默认关闭。用户在看到本报告摘要与待验项后回复“确认开始完成吧”，已记录Gate 3并进行本地归档/规格合并；此确认不是全平台功能通过，也不授权提交、推送、tag或真机安装。具体交付边界见delivery.md。
