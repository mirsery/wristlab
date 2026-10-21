# 当前阶段

Gate 1：用户“确认”，模式按推荐standard。Gate 2：用户确认design、三处取舍（推高/拉低措辞与±0.5展示分段、压力HRV仅方向、EnergyReport可选区间）、规格与测试计划；Phase 3选择全自动长程，Gate 3仍须用户确认。分支feat/metric-insights叠在PR #5（feat/watch-face-complications）之上，PR #5合并后rebase到main。

## Phase 3

S1完成：CONTRIB-001～005共5个新测试函数（TC-005参数化14例），RED为缺接口编译失败（work/insights-s1-red.log），GREEN后全量55 Core+5 workspace通过；iOS模拟器构建通过；首页无建议性文案静态检查通过。详情页“模式”同时改为中文标签，避免显示内部mode值（小偏离，见pending-adjustments）。

S2完成：TIMELINE-001～005共5个新函数。RED为缺接口编译失败；改动前先记录DemoData报告的准备度/压力/电量原值、841个电量点之和与108个压力桶（work/insights-s2-red.log），TIMELINE-001断言改动后完全一致。GREEN后60 Core+5 workspace通过，iOS构建通过。首页“一天的节奏”改为电量（含睡眠/运动区段）与压力两张共享时间轴的图，孤立桶用点标出、运动桶用方形点。

S3完成：SLEEPUI-001～003、TREND-001共4个新函数，RED为缺接口编译失败（work/insights-s3-red.log），GREEN后64 Core+5 workspace通过；iOS构建通过。新增SleepDetailView（时间轴、阶段、指标、小睡、演示标签），首页睡眠卡可进入详情，7日卡片加准备度/睡眠/负荷分段切换与有效天数、均值及VoiceOver摘要。首页睡眠阶段条的VoiceOver标签同时改为中文阶段名（小偏离，ADJ-002）。

C阶段：三路复审与东八区模拟器截图发现9项调整（ADJ-001～009），已全部处置并同步规格；ADJ-005（Gate 2决策3依据错误）需Gate 3复核。最终64 Core+5 workspace、build-apple（含Widget注册运行）、diff check通过。test-report.md已写，Gate 3待用户确认。用户同期提出“心情监测”想法，建议作为issue #6候选#13单独一轮（读HKStateOfMind自报，不从压力推断心情），待用户确认。
