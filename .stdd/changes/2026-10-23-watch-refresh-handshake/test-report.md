# Watch 刷新握手验证报告（Gate 3 未就绪）

## 改动与已知事实

旧“已请求”在sendMessage发送前赋值且无replyHandler，只能证明尝试发送。用户的真实卡住根因尚未通过设备链路复现证实；本次修复诊断缺口、即时返回现有快照以及冷启动先恢复缓存路径，不宣称手机上的问题已解决。

## RED / GREEN

- work/watch-refresh-red.log：新增协议与状态API缺失导致编译失败。首次沙箱运行因缓存权限失败，不作为RED。
- work/watch-responder-red.log：排除Swift Testing宏对mutating调用问题后，明确cannot find WatchRefreshResponder。
- work/watch-delivery-red.log：明确cannot find WatchSnapshotDelivery。
- work/watch-refresh-check.log：scripts/check.sh通过，174 Core + 6 workspace = 180测试；新增9 Core与1 workspace。测试仅使用合成数据。
- work/watch-refresh-apple.log：双端模拟器构建与两类组件注册检查；最终构建结果以该日志为准。未部署新版，不把构建记成安装或同步。
- git diff --check、STDD project-check通过。

## 追溯与缺口

| TC | 测试函数 | 实际覆盖 / 未完成 |
|---|---|---|
| TC-WRH-001 | unavailableDoesNotPretendRequestSucceeded | 状态模型覆盖；WCSession实际可达/激活待验 |
| TC-WRH-002 | cachedSnapshotRepliesBeforeSlowOrFailedRefresh / coldPhoneLoadsStoredSnapshotBeforeRefreshing | 实际共享Responder先回缓存再刷新；手机后台冷启动真机待验 |
| TC-WRH-003 | emptyPhoneReturnsExplicitResultOrNewSnapshot / repliesRoundTripWithoutAssumingSnapshotReceipt | 无快照、未连接、失败与成功协议；HealthKit真实故障待验 |
| TC-WRH-004 | requestWaitsForReplyAndCoalesces / timeoutAndLateReplyAreIsolated | 请求状态及迟到ID覆盖；真实15秒Task、WC回调与通道竞争未自动覆盖 |
| TC-WRH-005 | deliveryCommitsOnlyAfterSuccessfulPersistence / deliveryRejectsDemoOldRevisionAndUnconfirmedProducer / refreshDeliveryPersistsClearAndRejectsLateData | 适配器实际使用共享接收层；真实原子文件写入、重启、清除、迟到拒绝及失败保留内存已覆盖；设备存储保护和新手机确认UI待验 |

## 三路评审

代码审查无阻断；指出手机busy且无缓存时暂返回无快照，后续context补送。规格审查冷启动问题已修并复核关闭。测试审查接收持久化缺口通过共享接收层与真实文件测试补齐并复核无新阻断；实际WC与15秒任务覆盖缺口保留。

## 流程与失败模式检查

ci check-failures日志work/watch-refresh-stdd-check.log：TC扫描仅识别tests/test_*.py，错误报告0/5，本项目为Swift，不能将该命令记为通过；以上手动映射不伪装CLI结果。其余结构、唯一ID、SHALL、AND检查通过；范围、coverage、跨capability契约、anchoring与切片完成检查存在SKIP。

手动逐项检查：文件存在、范围仅本修复、没有以请求作接收证据、TC映射、每需求有场景、SHALL、AND数、失败分支、双端字段一致、接收后持久化、清除/版本/producer、冷启动缓存恢复均已审查。真实计时与WC并发、签名部署、用户双端同revision验收均标未验证。项目关闭coverage，不新增工具。经验CLI因缺requests不可用，使用本地经验文档记录，不修改上游。

## 剩余交付

待用户批准双端本地测试构建（暂不启用iCloud，保留源码及数据，不卸载）。尚无本轮实体设备安装、同revision快照接收或交互验收证据；Gate 3保持未确认，build保持in_progress。

## 后续授权与实际部署更新

用户已确认“暂不启用iCloud那边的能力，代码可以先做，这里先不开启iCloud 默认关闭”。默认构建改为不申请CloudKit权限，保留project-icloud.yml显式启用路径；配置复核无阻断，运行时不会创建CKContainer。签名包Info=false且无iCloud签名键，codesign严格核验通过，含Watch应用。

work/watch-local-check.log最终180测试通过；work/watch-refresh-device-build.log签名构建通过。手机安装日志确认sequence2108，手表安装sequence960、应用列表存在、启动成功。手机因Locked未能启动，需用户解锁前台，端到端数据同步未验。未卸载或清除应用数据，数据保留结果仍待用户体验确认。

默认配置最终build-apple.sh（work/watch-local-apple.log）双端编译成功，但iPhone注册宿主simctl launch退出3，系统日志libdispatch BUG，完整命令不通过；此前work/watch-refresh-apple.log组件检查通过不替代此结果。保留诊断work/widget-registration-test-ios/diagnostics.log，不扩大本修复去改系统或无关组件。STDD映射检查仍误扫Python文件而0/5，不能报全门禁绿。Gate 3继续等待真实验证，不请求用户把未完成项当通过。
