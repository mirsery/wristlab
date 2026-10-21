# 表盘组件与图标 Build 测试报告

2026-10-21；基于main b0a4f95的feat/watch-face-complications工作区。macOS、Swift6、Xcode27.1；iOS27.1/watchOS27模拟器。使用合成数据。

## 执行结果

- ./scripts/check.sh：通过，37 Core测试 +1工作区测试，0失败。原30测试回归，新增7函数（其中URL测试参数化9输入）。规格52个既有验收ID、31场景与12数值金例校验通过。新change为17 TC/17场景。
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-apple.sh：iPhone、Watch与Widget内嵌构建通过。
- generic/platform=iOS、CODE_SIGNING_ALLOWED=NO：真实设备架构构建通过。此产物未签名，不能安装，不代表设备运行成功。
- 真机签名构建（本地team覆盖，不提交团队配置）：通过；work/face-device-signed-build.log记录BUILD SUCCEEDED。
- 最终复跑显式使用完整Xcode，37+1通过；直接CLT复跑曾因SDK/编译器版本混用失败，已通过DEVELOPER_DIR修正执行环境。
- git diff --check：通过。coverage/e2e配置禁用，SKIPPED，不报虚构覆盖率。
- 本地日志（忽略提交）：work/face-s1-red.log、face-s2-red.log为新增接口前失败证据；face-final-check.log为37+1通过；face-apple-build.log和face-device-build.log为构建证据。
- CI状态以本分支PR检查为准，原main的CI不代表本轮分支通过。

## 17 TC 实际对照

“部分”表示已有自动或编译证据，但TC的全部平台要求尚未验收。TC注释存在不计作执行成功。

| TC | 结果 | 实际证据 / 缺口 |
| --- | --- | --- |
| TC-FACE-001 | 部分 | 四具体Widget编译；系统编辑器实际枚举与槽位安装待验 |
| TC-FACE-002 | 逻辑通过 | complicationKeepsMetricIdentityPartialQualityAndRealZero核对三指标字段 |
| TC-FACE-003 | 逻辑通过 | 同一测试保留真实0 |
| TC-FACE-004 | 逻辑通过 | complicationMapsMissingAvailabilityWithoutZeroGauges覆盖四缺失原因及独立性；View静态核对nil不建数值Gauge |
| TC-FACE-005 | 逻辑通过 | partial数值与描述断言；各family辅助文字外观另见FACE010 |
| TC-FACE-006 | 逻辑通过 | complicationExpiryUsesIndependentStrictBoundaries覆盖等于/超过、未来时间及整快照屏蔽 |
| TC-FACE-007 | 部分 | complicationCacheValidationClearAndDemoIsolation覆盖nil/JSON/schema/墓碑；实际App Group读取及清除后屏幕刷新待验 |
| TC-FACE-008 | 逻辑通过 | 同上拒绝demo DTO与原始demo receiver JSON；说明预览无写缓存路径 |
| TC-FACE-009 | 逻辑通过 | complicationTimelinePreparesDistinctExpirationTransitions含去重排序、过期/未来/clear及无过去entry |
| TC-FACE-010 | 未完成 | 编译及静态accessibility/privacy/containerBackground审阅通过；四family、系统着色/低亮度与VoiceOver实际体验待验 |
| TC-FACE-011 | 部分 | complicationRoutesRoundTripAndPreserveExistingEnergyKind通过；Widget点击冷/热启动未验证 |
| TC-FACE-012 | 逻辑通过 | complicationUnknownOrInjectedURLsReturnToOverview的9个非法URL输入通过 |
| TC-ENERGY-001 | 部分 | 原kind/cache/schema不变，Receiver原协议测试回归；升级已有表盘及实际重载待验 |
| TC-ENERGY-002 | 部分 | 失效模型/时间线通过；离线送达/清除和后台刷新待真机 |
| TC-ICON-001 | 部分 | 同母版两端1024无alpha，AppIcon配置/actool/三目标通过；真机系统图标待验 |
| TC-ICON-002 | 部分 | iPhone设置正常导航观察，Watch --face-guide观察；Watch更多菜单正常入口及真实系统操作待验 |
| TC-ICON-003 | 部分 | 实际说明页截图标签/数值及不写缓存的静态审阅通过；全部平台外观待验 |

8个TC纯逻辑通过；其余9个未完整关闭。12个TC有纯逻辑断言证据，不能据此报17/17或平台成功。

## 切片与评审

S1新增5函数、S2新增2函数；S3为静态资源/说明，按项目约束用资源检查、构建和实际截图，不写镜像单测。源代码产出完成；平台验收未完成，状态未伪标全部done。

C1三路独立评审：face_code_review、face_test_review、face_docs_review均返回。

- 代码评审发现外部路由保留演示、Watch首页显示过期值：已修复，改用共享显示模型并退出演示；复审发现开发参数覆盖外部冷启动路由的竞态，也已加守卫。
- 测试评审建议时间线已过期/未来/墓碑边界：已补充，37+1通过。
- 文档评审发现设计仍标Gate2待确认：已改为Gate1/2已确认，Gate3未确认。
- 无已知未处置的代码阻塞发现；缺少平台执行证据单独保留，不等于已通过质量验收。

## 运行观察与安装阻塞

[说明页实际截图](../../../docs/screenshots/watch-face/README.md)来自本机模拟器。iPhone走设置入口；Watch走--face-guide开发入口。预览明确标注合成，不能当作系统表盘。

Watch系统编辑器可打开，但当前选择的全屏表盘没有复杂功能槽，尚未完成Wristlab四组件选择。simctl openurl返回LSApplicationWorkspaceErrorDomain 115；因此未验证真实Widget点击，不能断言冷/热启动成功。补完方式：在配对Watch选含槽位表盘，分别选择四组件并点击；核对无缓存、过期、清除及系统着色。

用户已接入iPhone并授权测试后安装。检测到设备开发者模式关闭，Xcode已有个人团队，经自动配置后证书与三个target的签名构建通过。初次Watch profile的App Group不匹配已由Xcode更新修复；用户随后开启开发者模式；针对已连接iPhone重新生成含该设备的profile后，devicectl安装成功。用户手动信任开发者后，普通真实模式启动成功，并通过进程列表确认Wristlab仍运行。版本0.1.0(1)，iPhone16ProMax/iOS27.2。不得为绕过签名删除HealthKit/App Groups能力；证书、设备标识和真实健康数据不提交。

## 失败模式与工具限制

逐项检查见[failure-modes.md](failure-modes.md)，本地经验EXP-20261021-001，设计技术调整见[design-adjustments.md](design-adjustments.md)。

上游ci check-failures结果为5通过/4跳过/1错误（0/17 TC），因为按旧根tests/Python扫描，未读取Packages内Swift Testing；保留原失败日志，不修改固定上游或降低门槛。Canonical手动核对三capability、8 requirements、17 scenarios；TC矩阵以上述真实断言与平台证据为准。experience命令缺requests，直接检查本地经验目录；structure delta旧路径不适用，使用实际diff；extract-proposal未正确提取自生成视图，直接审阅Canonical。均未伪报CLI通过。

## 当前结论

实现与本地逻辑/构建检查完成，可进行开发签名安装与用户验收；尚不宣称所有17 TC或真机能力通过。iPhone真机安装与启动已完成；Gate3未批准，未合并或归档。实际表盘添加与点击、跨设备同步清除、后台刷新与HealthKit真数据仍需要补完。

## 真机安装补验

首次generic签名产物的profile未包含当前手机，安装被系统以0xe8008012拒绝；改用明确的设备destination并允许Xcode注册设备后修复。用户手动完成开发者模式及开发签名信任，devicectl install返回App installed，launch返回Launched application，随后进程查询确认运行。未读取真实健康记录、未截取手机健康界面。安装/启动仅证明应用能在该手机运行，不证明Watch或HealthKit授权通过。

## Watch 真机安装补验

2026-10-21，AppleWatchSeries9/watchOS27.0.1。用户开启开发者模式并完成开发配对后，Mac设备列表识别到真实Watch。明确指定该设备destination，Xcode自动签名/注册，WristlabWatch与内嵌Widget构建成功；devicectl install返回App installed，launch返回Launched application，随后进程查询确认WristlabWatch运行。安装的是普通真实模式，未添加--demo。

因此双端真机安装和启动通过。表盘四kind实际选择、点击冷/热启动、数据送达/清除、App Group实际读取与后台刷新仍未由安装证明，保留待验；未采集或提交真实健康数据、设备唯一标识及签名材料。

## 真实使用后发现的组件注册崩溃与修正

用户报告无法使用后，真实Watch发现4次WristlabWidget崩溃。两份记录的故障堆栈一致，用匹配UUID的本地调试二进制符号化，定位到metricConfiguration的configurationDisplayName。原始诊断仅保存在gitignored work/bug-diagnostics，不提交个人设备日志。

最小宿主执行生产配置body，确切复现：`Fatal error: Formatted text for configurationDisplayName is not supported`。根因是插值LocalizedStringKey在WidgetKit注册阶段不被接受。改为三个固定本地化名称，kind/数据/布局不变。

永久回归命令：`python3 scripts/test-widget-registration.py`。它复制生产Widget声明，仅替换main入口，逐个执行四种配置body；即使simctl在子进程崩溃时返回0，也要求四个OK与PASS标记。用git show保存的修复前源码执行--widget-source，退出1并复现同一fatal（RED）；执行当前源码，四组件全部通过（GREEN）。该测试已加入build-apple.sh，后续CI编译不能代替运行检查。

修复后37 Core+1 workspace、双端模拟器构建、四配置运行检查通过；真实Watch定向签名构建、更新安装与启动成功，随后的崩溃列表未见新组件记录。此结果只关闭注册崩溃，实际表盘布局/点击/同步仍待验。

手机问题另案诊断：用户明确为授权/刷新后一直加载、卡住或无反应。约231403条合成记录的61日计算在开发Mac Debug耗时11.36秒，构成性能风险线索，但尚无手机卡住时的线程证据，不能认定唯一根因或宣称修好。手机锁屏阻止启动取证，已请求用户解锁并复现。未读取真实健康缓存。

本次修正另经代码/测试/文档三路复审。已补齐测试宿主版本键、统一模拟器冷启动等待为300秒，并保留非零退出/超时输出；文档已区分签名安装通过与HealthKit/App Group真实行为待验。复审后的配置运行回归再次通过。

## 手机刷新卡住：诊断与恢复记录

2026-10-21，用户反馈授权/刷新后一直加载、卡住或按钮无反应。LLDB附加未取得可用线程栈，退出调试期间应用曾退出；未取得新的手机应用崩溃报告，不能判定为应用自身崩溃。后续结束调试会话。Time Profiler直接附加/系统采样通道异常或没有有效样本，均不作为根因证据。

重新恢复设备开发配对后，在gitignored work目录制作独立诊断构建：只标记授权、五类查询、计算、保存、呈现阶段，不记录健康数值或样本。保留原App数据。实际记录11次刷新，11次均完成；其中报告计算约0.8秒，未复现查询永久等待、计算长期占用或无限刷新。用户明确回复“现在能刷新并操作”。这只证明该次诊断版本恢复可用，不足以确定原故障根因；不得将临时日志或重新启动等同于代码修复。

随后已将手机恢复为当前分支不含诊断日志的正常版本，安装与启动成功，Wristlab进程存在且无debugserver。已检查仓库Apps/Core无DEBUG-refresh-20261021或诊断阶段字符串。原始设备信息和诊断输出不提交。正常版本再次刷新/页面操作的用户验证仍待反馈；表盘注册崩溃已有独立明确修复，手机卡顿根因仍保留未知。
