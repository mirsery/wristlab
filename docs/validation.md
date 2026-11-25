# 验证与范围 / Validation scope

## 2406 布局与 Watch 刷新退出修复（2026-10-24，Gate 3 已确认）

2405 的两项问题已定位修复并经用户真机确认：手机今天页双列卡片错位源于 `LazyVGrid` 默认垂直居中，改为等高顶对齐；隐藏导航栏的今天页补同色状态栏背板。Watch 退出经两份崩溃报告符号化为刷新回复闭包继承 MainActor、在 WatchConnectivity 后台队列触发隔离检查，改为 Core `WatchRefreshHandlers` 非隔离处理并加 `check.sh` 调用点守卫。`scripts/check.sh` 256 项、`scripts/build-apple.sh` 及新增 PCL/WRX 测试通过；2406 无 iCloud 签名构建同包覆盖两端、版本核对，未卸载或清数据。用户反馈“手表不闪退了，手机布局也好了”，覆盖前后崩溃目录无新增。VoiceOver、Home 键机型、iOS 17–26 及单独切页路径未验。详见 [布局报告](../.stdd/archive/2026-10-24-phone-care-layout/test-report.md) 与 [Watch 报告](../.stdd/archive/2026-10-24-watch-refresh-exit/test-report.md)。

## 手机今日关怀 2405 真机安装（2026-10-24，布局/稳定性未通过）

后续反馈：用户指出手机布局错位/遮挡，并反馈 Watch“仍闪退或无法打开”；定向复查已无 Watch 主进程、仅见 Widget。2405 不标为功能体验通过，根因待诊断；安装与初次启动回执只证明下述操作完成，不证明长期稳定。截图不复制入库，不记录真实健康数值。两项修复范围分别请求 Gate 1，未自行批准或修改生产代码。

用户在代码/模拟器归档后另行要求“真机安装验证下”，并确认两端已解锁。当前默认无 iCloud 包已完成签名构建和四包验签；手机从 2404、Watch 从 2402 同包覆盖至 0.1.0（2405），两端重新查询版本、普通启动及延迟主进程检查通过。未卸载、清数据、改生产源码或提交推送。详细回执及边界见 [2405 真机记录](../.stdd/archive/2026-10-24-phone-today-care/device-validation.md)。已请用户检查三卡/详情/滚动及 Watch 页面/刷新；当前尚无本版界面、真实健康读取或长期稳定性的用户确认，不能因安装成功将其记为通过。

## 手机今日关怀代码/模拟器验证（2026-10-24，Gate 3 已确认并本地归档）

PTC-001–006 的三卡图标/短句、连续电量、异常原因及原详情两类时间已实现，评分/健康权限/同步/iCloud 不变。最终 `scripts/check.sh` 通过 205 Core + 35 Workspace + 14 手机模型共 254 项；`scripts/build-apple.sh` 整体退出0：双端模拟器构建、两平台组件注册、4 项设置 UI 和 10 项关怀 UI 全部通过。当前模拟器构建在新建 mini 的完整 App 冒烟另 1 项通过，合计 15 项不同 UI 测试。

关怀 UI 与完整 App 均使用本轮新建 iPhone 13 mini / iOS27.0，合成演示五页签/指标详情、最大字体/长原因已核对。旧 Home 驱动未将 App 真正放后台，曾按阈值暂停；用户授权继续后改为激活系统设置并断言真实后台及返回，聚焦和全量均通过，没有改生产时钟迎合测试。报告、历史失败、CLI Swift 自动追溯限制及未验项见 [本轮报告](../.stdd/archive/2026-10-24-phone-today-care/test-report.md)。用户明确回复“确认本轮代码与模拟器验收，并本地归档”，Gate 3 已记录，[交付记录](../.stdd/archive/2026-10-24-phone-today-care/delivery.md)保留七项小偏差与未验项。没有操作真机、清已有数据、提交推送、开启 iCloud，真实健康/系统后台调度/完整 VoiceOver/性能未验。指定模拟器可用 `WRISTLAB_PHONE_CARE_SIMULATOR` 或 `scripts/test-phone-care.py --device <模拟器 UUID>`；完整 App 冒烟要求在隔离模拟器明确指定设备，脚本不安装/卸载正式 App。

## 已执行的逻辑验证

原main基线：30个核心测试与1个工作区测试通过；核心测试包含循环核对12组spec数值金例。对应应用源码的[CI运行](https://github.com/mirsery/wristlab/actions/runs/39454777037)已通过。

`Packages/WristlabCore/Tests/WristlabCoreTests/BusinessTests.swift`通过公共API覆盖：

- SCN-001/002/003：基线13/14日、常量历史尺度、准备度数值。
- SCN-006：压力完整/仅HR两条公式；12组JSON金例覆盖readiness、stress、batteryStep、exertion、targetRange、sleepDebt、regularity。
- SCN-009/011/012：分钟积分、30分钟与超30分钟缺口，以及确定性重放。
- SCN-014/015/018/019：卧床与分期不重算、无asleep不编造、债务缺失及跨午夜规律性。
- SCN-020/021/022/025：DST23/25小时、负荷映射/分区和目标历史缺失。
- SCN-027/028/029：旧epoch拒绝、清除不复活、空输入不出分数。
- 本地事务重开、anchor和报告同批持久化、磁盘失败回滚、旧任务revision拒绝、sample版本不回退、未变内容不刷新快照及非法缓存分数显示保护。
- 23日合成记录到完整报告；输入乱序得到相同结果。

此列表是实际测试覆盖记录，不声称全部47项验收或31个场景已全部完成。BoundaryTests还覆盖SCN-004/005夜间/日间隔离、SCN-010运动优先、SCN-016/017睡眠段与小睡、SCN-023/024去重和稀疏HR、SCN-030选源/新producer/未知schema/非法值、SCN-013/031删除重算与清除持久化。后续新增边界测试在此扩展；以源代码和CI结果为证据。

## 平台验证

CI执行`./scripts/check.sh`和`./scripts/build-apple.sh`，构建iPhone、Watch及Widget目标；截图来自运行的双端模拟器合成演示。[已通过的构建与截图运行](https://github.com/mirsery/wristlab/actions/runs/39454777037)同时记录于截图manifest；后续仅文档更新可复用指纹一致的截图。

此前本机仅有Command Line Tools，通过`scripts/swift-test.sh`显式发现已安装的TestingMacros插件，已能执行全部领域测试；没有绕过断言。

## 真机待验收

当前开发Mac已安装Xcode27.1，iPhone与Watch真机签名、安装与启动已通过；以下能力仍未验证：

- Apple健康真实授权、历史与增量/删除送达。
- 锁屏文件保护、系统后台执行机会和撤销读取后的可读变化。
- 配对Watch快照送达、断连重连、producer更换和离线清除。
- App Group与表盘组件安装/刷新、无障碍实机体验。

代码与模拟器可验证的部分完成后，仍需按H-001/H-005/H-007及P-004/P-005用真机补验。公开验证记录只写系统版本和结果，不上传真实健康数值。

## 表盘扩展：2026-10-21 本地 Build 验证

本轮新增7个Swift Testing测试函数，37个核心测试通过（参数化URL用例覆盖多个输入）；工作区测试及最终回归结果在STDD test-report记录。新增显示状态、真实零、按指标严格失效边界、损坏/清除/演示缓存隔离、预排时间线和URL白名单测试。两端图标为同一已确认母版的1024平方不透明导出；本机iPhone/Watch/Widget编译通过。

说明页已在双端模拟器观察并保存[实际截图](screenshots/watch-face/README.md)。当前watchOS27模拟器的simctl openurl返回LSApplicationWorkspaceErrorDomain 115；这不能当作路由成功证据，也不单凭该错误断言实际Widget点击失败。四组件实际安装、各family外观和冷/热点击仍待平台验收。完整17项TC对照见[本轮测试报告](../.stdd/changes/2026-10-21-watch-face-complications/test-report.md)。

真实设备架构未签名构建也已通过。已接入iPhone；通过Xcode现有个人团队生成开发证书和匹配的App Group/HealthKit profiles后，三目标真机签名构建通过。用户开启开发者模式并信任开发者后，针对设备更新profile，iPhone16ProMax/iOS27.2的安装、普通启动与进程运行查询通过（0.1.0/1）。WatchSeries9/watchOS27.0.1随后也完成定向签名构建、安装、普通启动及进程运行查询。双端安装通过；实际表盘添加/点击、健康授权与跨设备同步仍待验。

## 真机使用反馈：组件注册崩溃

安装与启动通过后，实际使用暴露Widget扩展在配置名称阶段崩溃。已用独立宿主运行生产配置复现相同fatal，并改为固定本地化名称。修复前运行回归失败，修复后四个配置通过；运行检查已加入Apple构建脚本。真实Watch已安装修复版并启动，尚不据此声称全部表盘操作或手机刷新正常。手机长时间加载问题仍在诊断。

手机卡顿的后续诊断：独立临时诊断版记录11次刷新全部完成读取、计算与保存，用户确认该版本能刷新并操作；原故障根因未确认。正常无诊断版已恢复安装和启动，用户进一步确认“正常版本也能刷新并操作”。本次报障恢复后未复现，但手机原卡顿根因仍未知，不能宣称已找到并修复对应代码根因。未将私人诊断文件或健康记录提交到仓库。

### Watch 空白页：缓存权限及布局修正（2026-10-21）

真实 Watch 已收到有效快照，但在设置系统管理的 App Group 根目录备份属性时被拒绝，缓存尚未写入。改为对同目录自有临时文件设置保护和备份排除，成功后原子替换原 watch-receiver.json；失败保留旧文件/内存。原子文件适配器由两端应用及工作区测试共用。生产测试覆盖策略失败、提交失败、保存/重开/clearData以及备份属性在原子替换后的保留。37 Core + 5 workspace、双端模拟器编译、四种 Widget 配置运行、普通签名构建通过。最终存储实现的真机诊断验证保存/备份属性/重启恢复通过；不含诊断的普通版已构建，安装与启动单独记录。46mm 模拟器真实空状态与合成报告完成铺满布局视觉检查。用户真机布局确认、全套表盘操作/后台系统调度及手机输入缺失仍待独立验收，不算 Gate 3 通过。

普通双端版本随后安装成功，启动命令均成功，二进制确认不含临时探针。用户实际布局反馈仍待补。

用户随后确认“已显示指标区域，布局正常”，本次 Watch 首页同步与铺满报障通过实际使用确认。缺失指标的输入问题及其余表盘验收继续独立保留。

### 当前健康来源与缺失原因说明（2026-10-21）

失活历史来源已从60日计算窗口的自动候选中排除；显式偏好/单组历史保留，来源变化重建并推进epoch。无电量起点现在区分最近相关夜晚缺HRV、对应RHR和基线不足，手机/Watch直接显示实际X/14进度与原因，详情提供操作建议；时效优先、真实0与未知原因回退保持一致。原评分数值及门槛不变。

50 Core +5 workspace、双端模拟器构建/四Widget配置运行及普通双端签名构建通过，三路复审发现项已闭环。合成13日不足场景完成双端卡片视觉检查，Watch实际点击及滚动说明通过。手机真实刷新已证明当前HR进入评分、压力available且fresh。最终普通两端已安装，Watch启动成功；用户解锁后iPhone重新启动成功、进程存在，用户随后明确确认“两端都有明确原因，详情能打开”，本轮正常版双端提示与详情操作验证闭环。Gate3未确认，不将此记为全部表盘或睡眠输入已验收。

### 解释与日内展示（metric-insights，2026-10-22）

只改iPhone展示与Core纯展示模型，公式、门槛、模型版本、HealthKit读取类型、Watch同步schema不变。新增14个Swift Testing函数：贡献方向/±0.5展示分段/差值、规格分段边界、电量驱动区间（与c515ff6的数值和顺序校验和一致）、时间线断线与裁剪、纽约25小时夏令时日、旧缓存解码、睡眠泳道（真实SleepCalculator含清醒与冲突段）与空值、7日趋势。64 Core + 5 workspace、双端模拟器构建与四Widget注册运行检查通过，[PR #7 CI](https://github.com/mirsery/wristlab/actions/runs/39632665463)通过并生成当前截图。

模拟器视觉检查使用东八区设备显示UTC合成报告，发现并修正时间按设备时区格式化的问题。VoiceOver仅静态审阅标签；真实数据下的首页图表、详情贡献、睡眠详情与7日切换尚未在真机验证。完整TC对照见[测试报告](../.stdd/archive/2026-10-21-metric-insights/test-report.md)。

### 长期趋势、个人基线区间与近7日回顾（long-trends，2026-10-22）

不扩大读取窗口或类型，不改公式。history扩为35个分析日并带逐日夜间HRV与静息心率；个人基线区间仅在今天准备度为夜间模式时提供，与其同一基线；趋势支持7/30日与五项指标；近7日回顾对比此前28日。新增9个测试函数（含复审变异补测），74 Core + 5 workspace、双端构建与Widget注册运行检查通过；模拟器合成截图检查趋势卡片与回顾卡片。真机与VoiceOver待验，Gate 3待用户确认。

### 心情记录与压力对照（mood-records，2026-10-22）

iOS 18+主动连接后只读State of Mind，与同时段生理压力并列；不推算心情、不判断因果、不进仓库或Watch。新增9个测试函数（中文表、配对边界、半开日、时间线范围、窗口与夏令时、标注），HKStateOfMind接口按本机SDK核对。模拟器只截了有记录态；授权与其余状态待真机，Gate 3待用户确认。

### iPhone小组件（phone-widgets，2026-10-22）

手机每次发布真实快照时原子写入iPhone App Group，演示不写入；小组件与表盘组件同一显示规则。新增3个Core测试（缓存校验含32KB边界、汇总与时间线、单项状态），iOS宿主注册运行检查加入build-apple.sh并在本地通过，用插值名称的源码复现fatal（RED）。小组件外观与系统添加、刷新尚无渲染证据，待真机验收；Gate 3待用户确认。CI apple作业超时提高到40分钟。

### 晨报本地通知（morning-brief，2026-10-22）

设置开启后请求通知授权；真实刷新得到当天报告、今天已有已完成主睡眠且处于分析时区05:00–14:00时，每个分析日推送一条（默认隐藏数值，前台也显示，清除撤回）。新增3个Core测试（发送条件、窗口与去重、文案与标注、隐藏模式）。通知授权、前台与后台送达、锁屏显示待真机验收；Gate 3待用户确认。

### 用户请求实体手表安装（2026-10-23）

用户本次明确要求安装手表，取代此前暂不安装的偏好；只构建Watch scheme，不覆盖手机上的2388版本或安装受iCloud签名限制的新手机包。work/watch-install-build.log：generic watchOS签名构建BUILD SUCCEEDED，WristlabWidget.appex已内嵌。work/watch-install-device.log：实体手表安装在连接建立后立即断开（CoreDeviceError 4000），未获得App installed确认，不能称安装成功。设备仍列available (paired)；已请用户戴上并解锁手表、手机解锁靠近并开启蓝牙/Wi-Fi后继续。未验证启动、快照或系统表盘添加。

用户再次要求安装后重试成功：work/watch-install-retry.log返回实体手表App installed，bundleID为com.mirsery.wristlab.watchkitapp，databaseSequenceNumber为936；work/watch-launch-retry.log确认Launched application。手机未更新。此证据仅确认真机安装与启动，页面交互、手机快照同步和系统表盘添加仍待用户实际体验。

用户随后反馈手表看不到App。重新查询work/watch-installed-apps-verify.log为空应用列表，work/watch-launch-verify.log明确返回requested application is not installed，因此撤回当前已安装的结论；此前瞬时成功回执不足以证明持续安装。重新安装work/watch-reinstall-verify.log失败：CoreDeviceError 3002、kAMDRemoteConnectError，远程手表连接不可用。当前安装未完成，需恢复设备连接后继续核验。

用户确认设备准备好后，work/watch-install-ready.log返回App installed（sequence 952），work/watch-apps-ready.log明确列出Wristlab 0.1.0 (1)，work/watch-launch-ready.log确认启动成功。延迟复查work/watch-apps-ready-recheck.log仍列出相同应用，因此本次安装、启动及随后应用存在性均已核实；用户可见页面与同步仍待体验。手机未更新。

### Watch 刷新握手与默认关闭 iCloud（2026-10-23）

用户报告手表卡在等待且请求后显示“已请求手机刷新”。该旧状态在发送前赋值，不能证实接收。新增请求ID、有界等待、手机回执、已有快照优先交付和冷启动从仓库恢复，接收统一校验并在落盘成功后确认。H-007/SC-001至005；新增9 Core与1 workspace测试，work/watch-local-check.log：174 Core +6 workspace共180测试通过。三路评审与冷启动/持久化复核完成。实际WCSession回调、15秒Task竞争及用户真机快照仍待验收，Gate 3未确认。

用户明确要求iCloud默认关闭、源码保留。默认构建不申请云签名权限，Info开关false；未来显式project-icloud.yml启用，独立生成云entitlement。两种生成配置校验通过；签名安装包验证无iCloud entitlement、含Watch应用，codesign严格校验通过。work/watch-refresh-device-build.log签名构建成功。

本轮已同包名覆盖安装两端，未卸载、未执行清数据：work/watch-refresh-phone-install.log确认手机安装（sequence 2108），work/watch-refresh-watch-install.log确认Watch安装（sequence 960）；work/watch-refresh-watch-verify.log列表存在，work/watch-refresh-watch-launch.log启动成功。手机启动work/watch-refresh-phone-launch.log被系统Locked拒绝，已请用户解锁打开手机App并在Watch请求刷新，尚不能宣称真实同步恢复或本地数据保留已由用户验收。

用户随后对解锁后前台刷新问题明确回复“已显示健康快照”：本轮首次同步卡等待的用户可见路径已通过真机反馈确认恢复。此反馈不证明双端数值/revision逐项比对、15秒超时、后台/断连调度或所有缓存边界已通过，也不代替完整Gate 3。

最终默认配置的work/watch-local-apple.log两端BUILD SUCCEEDED，但iPhone组件注册宿主的simctl launch返回3，诊断含libdispatch BUG；即使日志出现REGISTRATION PASS，也不将本次完整build-apple.sh记为通过。上一轮work/watch-refresh-apple.log的双端与组件检查通过，保留两次结果，不以历史结果替代最终警告。STDD ci check-failures仍因仅扫描Python测试误报0/5，手动Swift追溯及实际覆盖缺口见本change报告。

### Watch 独立健康报告实现（2026-10-23）

用户确认范围“设计吧”、确认设计“开始实现”。WI-L/WI-S十场景：Watch本地只读/独立仓库/同核心计算、显式本地或手机模式、独立设置、单展示包供App/表盘、两分区清除与停止标记、分页与取消。公式和14有效日门槛未变，默认iCloud关闭。共享适配器移入SharedHealth，iOS心情扩展隔离；新增25合成测试，最终185 Core+20 workspace=205通过（work/watch-independent-check.log）。双端构建及四Watch/一iPhone组件注册检查最终退出0（work/watch-independent-apple-final.log）；中间模拟器宿主失败日志保留，不忽略历史异常。

generic iOS含内嵌Watch/组件签名BUILD SUCCEEDED（work/watch-independent-device-build.log），codesign严格校验及Watch独立声明、HealthKit/App Group实际权限、默认无iCloud通过（work/watch-independent-signing-check.log）。三路只读评审与复核已修前台恢复、phone清除投影重启、pending作用域及成功回调后的取消窗口。STDD上游只扫描Python测试仍误报0/10，手工Swift映射见本change test-report，不称所有流程门禁通过。

本轮新包未安装；上一轮用户“已显示健康快照”不能证明本次Watch独立读取。实际Watch授权、手机断连前台刷新、历史覆盖、重连来源、重启/清除、锁屏、性能与组件视觉待用户设备验收。Gate 3未确认，不归档。

用户随后回复“继续”，已尝试同包名覆盖更新两端，未卸载或清数据。work/watch-independent-phone-install.log确认手机安装成功（sequence2116），但启动work/watch-independent-phone-launch.log因Locked被系统拒绝。work/watch-independent-watch-install.log在建隧道时超时（CoreDeviceError4000 / RemotePairingError1001），本次Watch新版安装未完成；应用列表虽有Wristlab 0.1.0 (1)，因新旧包版本号相同，不能据此认定独立新版已装。Watch启动也因remoteService不可用失败，已请用户解锁两端并保持手表亮屏后再试。尚无本次独立授权或刷新验收。

用户回复“已解锁并准备好”后重试：work/watch-independent-watch-retry-install.log确认同一独立包App installed（sequence968），work/watch-independent-watch-retry-verify.log列出Wristlab，work/watch-independent-watch-retry-launch.log及work/watch-independent-phone-retry-launch.log均明确Launched application。安装与双端启动已确认，未卸载或执行清数据。已请用户在Watch进入独立设置主动连接健康，先验证本地报告/校准原因；手机App退后台不等于物理断连，完全断连、重启、清除、锁屏和性能仍需分别验收，Gate 3继续未确认。

### Watch 失败恢复稳定性（2026-10-23，真机按用户要求暂缓）

用户回复“暂时不测试”，随后明确暂缓真机。本次在WI-L-004/005、WI-S-003既定范围修复失败后仍显示进行中、手机投影成功重试保留旧错误、同步或写失败掩盖待清理/不可读缓存提示的问题。新增5项合成workspace测试，最终185 Core+25 workspace=210通过（work/watch-stability-check.log）；双端模拟器构建及四Watch/一iPhone组件注册完整命令退出0（work/watch-stability-apple-final.log），中间模拟器宿主退出3仍保留日志。三路只读复核完成，CLI validate/project-check及diff空白检查通过；Python-only TC扫描仍报0/10，未声称全部流程门禁通过。

未操作实体设备，本次修改未安装；手机与Watch仍是此前安装的独立版本。真实独立授权/断连读取、重启/清除、锁屏、耗电性能与组件视觉仍待验，Gate 3未确认。默认iCloud关闭，未新增读取类型或调整评分公式。

用户随后要求“真机验证”，已恢复设备状态查询，两端available (paired)；最新稳定性签名构建成功（work/watch-stability-device-build.log），沙箱内证书信任检查失败后，升级权限对同包复核签名和默认无iCloud通过（work/watch-stability-device-signing-final.log），未改系统信任。安装前用户转而提出Watch界面/图表/计数/表盘不足，已说明暂停安装并确认计数范围。本轮没有install/launch操作或独立健康读取反馈，不能记为安装或业务验收。

### Watch日常关怀版：代码/模拟器阶段（2026-10-24）

本轮实现关怀/活动/状态三页、图标短标签、只读日常活动、当天私有心情及新活动组件。`scripts/check.sh`实际231项通过（196 Core+35 workspace，新增21），`scripts/build-apple.sh`双端模拟器构建和5Watch+1iPhone生产配置运行注册通过，Diff/规格结构通过。运行合成SwiftUI观察三个首屏，顶部更多图标对比度已修；不把截图当滑动或VoiceOver证据。

完整追溯/RED-GREEN/审查与缺口见[本轮报告](../.stdd/archive/2026-10-23-watch-daily-care/test-report.md)。15个TC均有代码测试引用，不代表15完整平台场景通过；辅助CLI仍有Python-only扫描误报及coverage/canonical跳过，未伪称全绿。Crown/辅助字号/VoiceOver、各组件family/低亮度及真实健康/锁屏/断连待验。本轮遵守预授权不操作真机、不提交推送、不开iCloud；用户随后回复“确认开始完成吧”，Gate 3按代码/模拟器阶段及保留上述缺口批准，已本地归档合并。此前历史安装记录不证明本轮新包已安装。

### 关怀2401真机发现与calendar修复（2026-10-24）

用户另行要求真机验证后，默认无iCloud签名包2401已同包覆盖两端并核对版本，解锁后普通启动回执成功，但用户确认Watch闪退，因此不计功能通过。过滤异常元数据复现“Date components require a calendar”；手机另报“无数据，刷新已取消”，点连接无反应，未认定权限拒绝。详细[设备记录](../.stdd/archive/2026-10-23-watch-daily-care/device-validation.md)与[修复设计](../.stdd/archive/2026-10-24-watch-activity-calendar-crash/design.md)分开；修复尚待2402实际验证，不卸载清数据、不导出健康记录。

最新重试：手机已同包覆盖并实际核对2402、普通启动且后续主进程仍存在；健康读取问题仍未验证恢复。Watch开发连接报1001/1035，开发pair返回paired后安装仍被拒绝，不能用手机的内嵌包或pair回执证明Watch已更新。手表2402版本、稳定运行与真实活动刷新继续待验，未unpair或清数据。详见[修复阶段报告](../.stdd/archive/2026-10-24-watch-activity-calendar-crash/test-report.md)。

### 手机连接反馈与任务生命周期2403（2026-10-24）

手机2402仍“连接可点无反应”，用户另行确认手机修复Gate1/2。隔离编译生产DashboardModel复现授权等待无反馈、调用者取消与并发旧运动重读丢失，已补模型单任务、阶段提示、缓存原路径重试及显式停止保护。14个新合成函数及原231项全量回归通过，双端Apple构建和平台注册通过，2403四包签名/版本/组/HealthKit/无云验证通过；实际手机安装与健康可读另验，Watch重启后开发连接1035不计通过。详细[阶段报告](../.stdd/archive/2026-10-24-phone-health-connection/test-report.md)保留所有缺口，未清真实数据、增权限或开启iCloud。

手机2403实际覆盖安装sequence2188、版本0.1.0（2403）及普通启动已确认；已请用户点击连接并只回报状态文字。健康读取最终结果待反馈，Gate3未批准；Watch安装不因手机更新自动计通过。

### 最终补漏与本轮真机反馈：手机2404 / Watch2402（2026-10-24）

2403用户明确是在首页设置弹层点击无反馈：原设置状态在长表单底部，首页进度被遮住。补按钮旁状态、忙碌标签/进度和防重，不自动关闭设置或改权限。生产设置视图实际点击UI原行为RED、修后4项GREEN，最终245项Swift回归、双端构建、日期/组件探针及4项UI全部通过。UI宿主使用合成适配器并直接嵌入设置，不冒充完整首页sheet导航或真实授权。

手机2404已同包覆盖sequence2204、核对0.1.0（2404）及普通启动；用户从实际设置入口操作后回复“已更新本地报告”。手表开发连接恢复后查旧2401，再实际覆盖2402（sequence1000）、核对版本/普通启动/延迟主进程；用户回复“不再闪退，页面可打开”。两端本轮关键故障已有用户真机反馈；不扩展成各健康类型/评分、活动值、表盘、后台和性能全验。没有卸载清真实数据、导出样本、加权限、开iCloud或提交推送；两个change的最终Gate3报告确认仍待用户。

最终Gate3用户明确回复“确认，本轮修复验收并本地归档”。两份修复记录已归档并合并规格；仅验收上述手机连接和Watch闪退故障，保留未验项，不提交/tag/push或上传经验。交付阶段只改文档/基线，未再改App代码或操作真机。
