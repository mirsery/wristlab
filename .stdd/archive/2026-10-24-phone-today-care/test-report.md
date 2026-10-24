# 手机今日关怀验证报告（代码/模拟器 Gate 3 已确认并本地归档）

日期：2026-10-24。未提交工作树；没有创建提交或标签。范围仅 PTC-001–006，对应 P-010/metric-insights 的手机三指标展示。

## 行为变化

- 今天页原三卡改为图标与状态短句，首页不显示或朗读三指标分数；运动中和仅心率估算单独标明，不推断心情。
- 电量用连续填充，不新增等级；有效 0、缺失、校准、失败和过期分开处理，原因来自原 MetricExplanation。
- 原详情保留有效数值/贡献/原因/模型，分别显示有效观测与报告更新时间；未知报告来源不伪造。
- 直接沿用手机指标有效期，前台展示计时不触发读取、不引入 Watch TTL；演示冻结报告时间。
- 大字体单列、文本换行，原日计划/睡眠活动摘要、页签和路由保留。

## 实际检查

| 检查 | 结果 | 证据 |
|------|------|------|
| scripts/check.sh | 通过，205 Core + 35 Workspace + 14 手机模型 = 254 Swift 测试 | work/phone-care-check-verified.log |
| 新纯展示回归 | 9 项包含段位/舍入、情境、0/nil、原因、时效、回拨、贡献过期与辅助标签 | PhoneCarePresentationTests.swift |
| 双端模拟器构建 | 两端 BUILD SUCCEEDED，整个 build-apple.sh 退出 0 | work/phone-care-apple-verified.log |
| 组件注册与设置 UI | 两个平台组件探针及 4 项设置 UI 通过 | 同上 |
| 关怀生产 UI 宿主 | 最终 10/10 通过，0 失败、0 跳过，包括真实后台返回 | 同上 |
| 前后台诊断/聚焦 | Home 的旧驱动没有实际退后台；改为激活系统设置并验证后台/前台状态，聚焦和完整回归均通过 | work/phone-care-resume-settings.log / work/phone-care-apple-verified.log |
| 完整 App 窄屏冒烟 | 当前模拟器构建重新安装到本轮隔离 mini，1/1 通过：三卡→原详情、返回、五页签、合成标记 | work/phone-care-full-app-verified.log |
| 文档/Swift 追溯 | 六场景均有 TC/测试函数，逐场景 AND ≤3；spec 结构检查和 git diff --check 通过 | 本轮检查输出，canonical/specs/code |

最终合计 254 Swift + 15 模拟器 UI（设置 4、关怀 10、完整 App 冒烟 1）通过；聚焦重复运行不重复计数。两平台组件注册另计为探针，不冒充 UI 测试。

环境：完整 Xcode 的 iOS 27.1/watchOS 27.0 SDK；通过 DEVELOPER_DIR 选择，不修改系统 xcode-select。最终关怀十项和正式 App 冒烟均显式使用本轮新建 `5D50EBCB-0805-44A0-8E55-111B7F7F1CEA`，iPhone 13 mini / iOS 27.0，非真机；设置回归和 iPhone 组件探针仍按原脚本选择兼容模拟器。

已人工查看最终 `work/phone-care-verified-attachments/` 的最大辅助字体、单列、长缺失原因与分屏续图：文字按行换行、可滚动到详情入口，无卡片固定高度裁切。完整 App 的标准字体三卡及页签截图见完整冒烟 xcresult；这是选定模拟器的视觉证据，不是全设备或完整 VoiceOver 验收。

## RED/GREEN 与早期失败

- Core RED：新增类型不存在，真实编译失败见 work/phone-care-core-red.log；沙箱缓存报错不作为 RED，获得工具授权后重新执行才记录。实现后 Core GREEN，最终完整回归如上。
- UI RED：旧生产 SmallMetricCard 仍显示数值和 /100，状态断言失败见 work/phone-care-ui-red.log；旧宿主没有新压力卡引发的第三条失败不是评分逻辑复现，不计作旧三卡全链路 RED。
- 初轮生产 UI 暴露按钮语义丢失，增加 isButton 后聚焦测试通过；并发运行同一宿主造成一次运行器中断，不计产品故障。
- 后续运行发现相对启动 8 秒过期夹具不稳定、导航返回选择器及合成过期控件未保留到详情，均只修测试宿主与返回操作，未放宽产品时效。早期日志保留，不以删除失败来报告通过。
- mini 早期九项中八项通过、一项因上述宿主控件缺失失败；不能称这次九项全绿。最终修正后的全量关怀结果独立记录。

## 六 TC 追溯

| TC | 生产实现 | 测试与证据 |
|----|----------|------------|
| TC-PTC-001 | PhoneCarePresentation | readinessBoundariesAndRounding / pressureBoundariesAndContext |
| TC-PTC-002 | PhoneCarePresentation / PhoneCareViews | energyZeroAndMissing / ScorelessCards / ZeroSurvivesInDetail |
| TC-PTC-003 | MetricExplanation 接入 | missingAndCalibrationReasons / MissingHasReasonAndUnknownSource / LargestTypeMissingReasons |
| TC-PTC-004 | PhoneCareClock / 原 isStale | exactExpiryAndFutureObservation / noSnapshotTTL / clockRewind / ForegroundExpiry / DemoFreezesReportClock / OpenDetailExpires / ResumeReevaluatesClock |
| TC-PTC-005 | 原路由 / 生产 MetricDetailView | ThreeProductionDestinations / 两类时间具体值 / 贡献正反矩阵 / FullAppTodayNavigation |
| TC-PTC-006 | PhoneCareViews / 原页签 | scorelessAccessibility / LargestTypeCardsRemainNavigable / LargestTypeMissingReasons / 窄屏正式 App 截图 |

函数名实际包含 TC_PTC 编号；本表缩写不作为测试运行器选择器。六场景均有自动测试资产不等于六场景所有手工/真机项已验证。

## 三路评审与偏差

代码评审：1 个 P2（回拨时钟）已修复并只读复核关闭。测试评审：2 个 P2（已打开详情时效、不同时间与贡献正反断言）已补齐；第三轮只读复核无新增阻断项。文档评审：无阻断性行为偏差，旧状态文案已同步。恢复后另完成三路增量只读复核：真实后台驱动有效，无产品/权限扩展；直接按钮断言和时间证据边界已收紧。评审代理均未运行设备测试。

设计调整见 design-adjustments.md；十四类核对见 failure-mode-review.md。本地新增 EXP-20261024-015，参考既有 EXP-013/014，不修改全局记忆或上传经验。

## 降级历史与恢复验证

此前前后台用例导致完整执行为 9/10（90%）。按预授权阈值曾停用 full_auto、降级普通模式并暂停，未伪造 Gate 3。随后用户明确回答“继续排查模拟器测试环境（推荐）”，本次仅按普通模式恢复，不重启旧长程授权。

诊断确认 Home 后 app.state 仍为 runningForeground，不能把其后的 4 秒断言当真实后台恢复故障；4 秒不是 PTC-004 的原 30 秒上限。临时 task 替换无效已撤回，保留已确认的 TimelineView + 实际 Date 方案。本次测试改为显式激活系统设置，确认设置前台及关怀宿主后台/挂起，等待后激活宿主并确认前台；隔离 mini 聚焦 1/1 通过，随后完整 10/10 及完整 build-apple.sh 均通过，没有改生产代码、系统设置或权限。旧失败日志保留，不删除失败来伪造通过。

增量三路只读评审通过。证据仅证明真实后台返回后显示过期；+2 秒期限可能在启动设置期间到达，不能独立证明期限恰好在后台跨过。原滚动 helper 已从恢复后的状态断言中移除，直接查询原按钮；不把此用例扩大为调度精度或真机保证。

## 工具限制与未验项

- stdd ci check-failures 非零：上游仅扫描 Python 导致 Swift TC 为 0/6，能力/锚点路径也未识别、AND 全局累计 15；已人工核对六 TC 与 canonical，但不宣称该 CLI 全绿。canon verify 的两项只校验 proposal。
- 项目未启用行/分支覆盖率、SwiftLint 或通用 E2E 门禁；不捏造覆盖率。使用实际 Swift、Xcode、UI 和 diff 检查。
- 最大字体截图只证明所选模拟器状态下文字可换行/滚动；自动元素断言不等于完整 VoiceOver 手势验收。系统墙钟回拨真实调度精度、未安装的系统版本、性能与系统后台任务/刷新调度未测；真实前后台切换后的过期显示已在指定模拟器验证。
- 没有真实 HealthKit 授权或各类型健康数据、Watch 同步、表盘真机验收。本轮不安装/启动/卸载真机、不清已有数据、不改评分或有效期、不新增权限/通知、不启用 iCloud、不提交推送。

## Gate 状态

Gate 1/2、本轮预授权及暂停后的继续排查均有用户原话。切片 2/2 已完成，C1–C7 有实际记录。用户随后明确回复“确认本轮代码与模拟器验收，并本地归档”，已通过 CLI 记录 Gate 3 并归档；验收包含七项小偏差和已披露未验项，仅限代码/模拟器。本报告不是覆盖稳定真机版的授权，不宣称产品全面验收。交付与归档后检查见 delivery.md。
