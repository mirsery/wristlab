# Watch独立报告验证报告（Gate 3待真机验收）

## 行为与实现

手表主动连接只读HealthKit，独立仓库/profile与同一核心算法；显式本地/手机模式，单原子展示包投影给App/Widget，旧安装保持phone模式。前台与手动刷新；无专用后台观察/常驻会话。健康类型、公式和14有效日门槛不改，iCloud保持关闭。停止本地和手机clear各自分区，晚回结果不能复活。源码未提交或建立新分支。

## RED与GREEN证据

| 日志 | 证据 |
|---|---|
| work/watch-independent-s1-red.log | cannot find WatchDisplayEnvelope；S1新增模型测试先失败 |
| work/watch-independent-s1-green.log | 初始7测试及原回归通过（后续新增合并进最终） |
| work/watch-independent-s2-red.log | 排除目录不存在后，真实WatchReportModel API缺失编译失败 |
| work/watch-independent-s2-green.log | 调整测试MainActor回调声明后生产协调器用例通过 |
| work/watch-independent-s3-red.log | HealthReadBuffer缺失的RED |
| work/watch-independent-pager-red.log | 生产HealthBatchLoader缺失的RED |
| work/watch-independent-cancel-red.log | 成功回调后取消用例因isCancelled API缺失RED |
| work/watch-independent-check.log | scripts/check.sh最终185 Core +20 workspace =205测试通过；本轮新增11 Core+14 workspace共25 |
| work/watch-independent-apple-final.log | 最终scripts/build-apple.sh退出0；两个BUILD SUCCEEDED、Watch四种及iPhone一种组件注册PASS |
| work/watch-independent-device-build.log | generic iOS含内嵌Watch/组件签名BUILD SUCCEEDED，仅构建未安装 |
| work/watch-independent-signing-check.log | codesign严格校验、Watch独立运行标记、用途说明、真实HealthKit/App Group权限及默认iCloud=false通过 |
| work/watch-independent-project-check.log | STDD project-check通过；git diff --check通过 |

首次与中间运行有真实失败：测试宏mutating限制在前轮避免；本轮MainActor测试回调声明、注入writer缺目录、snapshot贡献裁剪导致的完整report对照差异均已修正测试设置，不改评分。投影失败测试原用空记录，原仓库会复用相同快照时间；改为有不同合成输入才能真正验证新仓库结果未展示。中间iPhone模拟器组件宿主有simctl退出3/libdispatch异常，未删除历史日志；最终完整命令本次退出0，不据此推断所有运行时稳定性。

## SC/TC→生产路径追溯

| 场景/TC | 主要测试（函数名称含TC后缀） | 生产路径与范围 |
|---|---|---|
| WI-L-001 / WLOCAL-001 | passiveStartDoesNotReadAndIndependentConnectWorks / foregroundRefreshesOnlyEnabledRealLocalMode | 实际WatchReportModel+fake reader，主动前无读、独立连接、前台/demo/stopped；HealthKit真机未验 |
| WI-L-002 / WLOCAL-002 | watchUsesSameEngineAndClock | 同输入/profile/asOf全部四指标、sleep与时间对照；既有Core13/14日/缺失/0/未来金例仍通过，实际历史未知 |
| WI-L-003 / WLOCAL-003 | localSettingsAreIndependentAndValidated | 实际repository.configure及无maxHR默认/范围拒绝，无健康读 |
| WI-L-004 / WLOCAL-004 | clearWinsOverLateReadAndRequiresReconnect / stopMarkerFailureDoesNotClaimDeletion / cleanupFailureRemainsStoppedAcrossRestart / stopMarkerIsDurableAndRejectsProjection | 停止标记与清理失败、真实文件重开、残留记录清理、晚回不复活 |
| WI-L-005 / WLOCAL-005 | readFailurePreservesSnapshotAndRevision / pagedDeletionWinsAndReadLimitIsBounded / HealthBatchLoaderTests四项 | 生产分页循环与buffer：删除优先、上限、第二页失败、anchor停滞、Task取消及reader代次失效；实际HK回调需真机 |
| WI-S-001 / WSOURCE-001 | initialAndLegacyMigration | 无缓存不选源，旧缓存迁phone；源码初启迁移与测试同模型 |
| WI-S-002 / WSOURCE-002 | localSelectionNeverMixesPhone / phoneReceptionAndModeSwitchDoNotMix / modeSwitchDiscardsLateLocalRead | 实际协调器收到phone不抢显示，切换晚回隔离 |
| WI-S-003 / WSOURCE-003 | failedProjectionKeepsCommittedSelection / repositorySuccessProjectionFailureRetriesAndModeFailureKeepsSelection | 原子writer故障、仓库成功投影失败、模式写失败、真实磁盘选择保留及重试 |
| WI-S-004 / WSOURCE-004 | phoneClearPreservesLocalReport / clearedPhoneProjectionRetriesOnDiskRestart | 本地不被phone clear抹除，phone清除落receiver但投影失败后真实重启补偿 |
| WI-S-005 / WSOURCE-005 | displayRejectsDemoAndUnknownSchema / corruptedProjectionDoesNotUseLegacyCache / corruptedDisplayNeverFallsBackToPhone | 拒绝demo/未知schema、损坏包不回退phone；既有producer确认测试通过 |

UI操作、真正HK授权/历史、系统锁屏保护和组件渲染不由上述合成测试证明。configure后投影失败已在下述稳定性补测中增加专门故障测试；同输入14日边界复用原引擎测试，不声称新写了另一套算法验证。

## 三路只读审查

代码、测试、规格三个代理完成审查与复核。前台恢复、phone投影重启、pending清理作用域、成功回调后取消窗口均修复；测试补真实磁盘重启与生产分页，不再只测DTO/假重启。复核未发现剩余明确代码阻断；不将审查当运行或设备验收。

## 门禁和失败模式审阅

work/watch-independent-stdd-check.log：ci check-failures仍报0/10，因为上游只扫描tests/test_*.py，本项目Swift测试未被识别；不得声称命令通过或伪造Python包装。唯一10TC、SHALL、AND及两capability契约检查通过；范围、coverage、canonical项目路径锚定及切片完成记录有SKIP。CLI validate/project-check通过不代替完整门禁。

人工检查已执行：范围与C1-4一致、输入/基线/缺失不放宽、同核心公式、source与producer分离、两份缓存不混合、原子显示提交、停止标记先写、旧任务失效、schema/坏文件/重启迁移、演示隔离、旧phone通道兼容、默认无iCloud及真实签名均已核对。coverage在项目配置关闭；无额外formatter，不新增工具。经验CLI缺requests，本地经验文件已记录，不修改上游。真实权限、HK取消回调、锁屏、耗时/内存/耗电以及系统组件调度检查SKIPPED：需要用户设备交互，不填占位通过。

## 尚未完成

本轮新包未安装；手机与Watch保留此前已验证同步包。下一步经用户准备后同包名覆盖更新，Watch主动连接健康；分别验证断开手机、真实可读历史/数据不足原因、重连不抢显示、前台恢复、App/表盘同源、重启与清除。Gate 3未确认，Build保持in_progress，不归档也不把“有公式/可构建”称成“实际可独立出分”。

## 用户授权继续后的安装尝试

用户回复“继续”。手机同包名覆盖安装成功，work/watch-independent-phone-install.log：sequence2116；启动因Locked拒绝。Watch安装work/watch-independent-watch-install.log未成功：CoreDeviceError4000 / RemotePairingError1001隧道超时；后续列表只有与旧包相同的0.1.0 (1)，不能证明本次新版存在，启动remoteService也不可用。未卸载、未清除数据。已异步请用户戴上解锁Watch保持亮屏，手机解锁靠近、Wi-Fi/蓝牙开启后重试。独立真机验收与Gate 3继续未完成。

## 解锁后的安装与启动确认

用户“已解锁并准备好”后，work/watch-independent-watch-retry-install.log确认独立新版安装sequence968，retry-verify列表有App；watch-retry-launch和phone-retry-launch均确认启动成功。手机此前sequence2116的新包与本次Watch来自同一签名构建。未卸载或清数据。已请用户在Watch主动连接健康并观察本地报告/真实缺失原因；尚无该步骤反馈。手机App退后台不能证明完全断连，后续还须完全断连刷新、重启、两分区清除等测试，不能据安装成功批准Gate 3。

## 暂缓真机后的稳定性补测

用户先回复“暂时不测试”，再明确“继续优化吧，暂缓真机的验证测试；”。本次仅处理已确认WI-L-004/005与WI-S-003的错误状态和重试，不扩展功能范围、不改变公式、权限、来源选择、清除边界或iCloud默认关闭；没有操作实体设备，本次修改未安装到两端。

读取、授权、设置、切换及清理失败后状态不再停留在“正在”阶段。手机投影成功重试只移除对应过时错误；本地缓存不可用及待清理错误优先保留，不被同步成功或另一次写失败掩盖。错误来源采用私有枚举区分，不匹配文案判断。

新增5个workspace测试：failedReadAndAuthorizationHaveTerminalStatuses_TC_WLOCAL_005、configureProjectionFailurePreservesDisplayAndCanRetry_TC_WSOURCE_003、phoneProjectionRetryClearsObsoleteError_TC_WSOURCE_003、phoneSuccessPreservesPendingCleanupNotice_TC_WLOCAL_004、phoneSuccessRestoresUnavailableLocalCacheNotice_TC_WSOURCE_003。覆盖实际configure后的投影写失败、保留旧展示并重试，以及真实文件清理失败后的同步/切源/停止写失败。所有输入均为合成数据。

RED证据：work/watch-stability-red.log、watch-stability-notice-red.log及watch-stability-switch-red.log。切源测试曾修正故障注入顺序；最终switch-red的两项失败才是对应生产缺陷证据。GREEN：work/watch-stability-check.log，185 Core +25 workspace共210测试通过；work/watch-stability-apple-final.log完整build-apple.sh退出0，双端模拟器BUILD SUCCEEDED、四Watch/一iPhone组件注册通过。中间watch-stability-apple.log出现simctl launch退出3，保留该异常，不以最终通过否认中间失败。

代码、测试、规格三路只读复核均结束，清理提示被投影成功或切源失败抹除的发现已修复并补测，最终未发现剩余明确阻断。git diff --check、CLI validate与project-check通过。work/watch-stability-stdd-check.log的Python-only扫描仍报0/10，不宣称所有STDD门禁通过。实际独立授权、断连、重启/清除、锁屏、性能及组件视觉继续待验；遵从用户要求暂缓，不请求恢复设备验证。Build保持in_progress、Gate 3未确认。

## 恢复真机准备后转向Watch体验反馈

用户要求“真机验证”后，已查询设备两端均available (paired)，并用默认关闭iCloud的配置签名最新稳定性包。work/watch-stability-device-build.log记录BUILD SUCCEEDED；沙箱内签名校验遇CSSMERR_TP_NOT_TRUSTED，升级权限复核work/watch-stability-device-signing-final.log确认手机/Watch/两组件签名有效、无云权限，手机云运行开关false，Watch独立声明/只读用途/HealthKit及应用组一致。未绕过证书校验、未修改系统信任。

安装前用户提出手表UI、图表、“运行计数”和表盘不足，已暂停覆盖安装并询问计数含义；本轮没有install/launch操作或新独立读取反馈。设备仍是之前已安装的独立版本，不把本次构建/设备可见记为新版安装或业务验收。后续体验调整另走范围与设计确认，不由该反馈批准运动录制、写权限、后台常驻或综合周报Gate 2。
