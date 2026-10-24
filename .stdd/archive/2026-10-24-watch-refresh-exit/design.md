# Watch 2405 刷新退出修复设计

## Context
从手机代理目录取回 Watch 2405 的两份崩溃报告（2026-10-24 13:20:04 / 13:20:25，Watch OS 27.0.1，build 2405），只提取异常类型与调用栈，原始 .ips 留在 gitignored `work/watch-exit-crash/`，不入库：
- 两份完全一致：`EXC_BREAKPOINT / SIGTRAP`，故障线程为 WatchConnectivity 的后台 `NSOperationQueue (QOS: UTILITY)`。
- 用匹配 UUID（A29D0A89…）的 `WristlabWatch.debug.dylib` 符号化：`WatchConnectivity → thunk ([String: Any]) -> () → closure #2 in WatchBridge.requestRefresh() → libswift_Concurrency → libdispatch _dispatch_assert_queue_fail`。

根因：`WatchBridge` 是 `@MainActor` 类，`requestRefresh()` 里传给 `session.sendMessage` 的 `replyHandler` / `errorHandler` 是闭包字面量，在 Swift 6 下继承 MainActor 隔离；`WCSession.sendMessage` 的 handler 参数没有 `NS_SWIFT_SENDABLE`（SDK 头文件已核对），且以 `@preconcurrency import` 引入，编译器因此在闭包入口插入动态隔离检查（SE-0423）。手机回复后 WatchConnectivity 在后台队列回调 → 检查失败 → 进程被 trap。该闭包由 `2026-10-23-watch-refresh-handshake` 引入；main 上旧实现 `replyHandler: nil`，不走回复路径，但其 errorHandler 闭包写法相同，错误路径理论上同样可能 trap（推断，未在设备复现）。

范围核对：同类 API 只有这一处。HealthKit 的 query / background delivery 回调在 SDK 中均标注 `NS_SWIFT_SENDABLE`，不受影响；`WatchBridge` 其余 WC 委托方法已是 `nonisolated`。两份报告均为刷新路径；「切页退出」没有对应报告，修复后真机复验时一并观察，若仍退出则另取报告，不在本轮推测。

## Decisions
1. **把回复处理抽成 Core 中非隔离、`@Sendable` 的 handler 工厂（推荐）**：`WristlabCore/WatchRefresh.swift` 新增 `WatchRefreshResponse`（`.reply(WatchRefreshReply)` / `.unreadable` / `.undelivered`）及 `WatchRefreshHandlers(requestID:deliver:)`，持有 `@Sendable` 的 `reply` / `failure` 闭包：在 WC 回调队列上只取 `Data` 并解码、核对 requestID，再 `Task { @MainActor in deliver(result) }`。`WatchBridge.requestRefresh()` 把这两个函数值传给 `sendMessage`，原有 MainActor 内的状态文案与 `refreshState` 逻辑不变。`WatchRefreshHandlers` 的属性类型禁止在 Core 内放入 MainActor 闭包；但 `@preconcurrency import` 下 `WatchBridge` 仍能无告警地给 `sendMessage` 传闭包字面量，因此 `scripts/check.sh` 增加 grep 守卫：`Apps/` 中 `replyHandler:` / `errorHandler:` 后不得紧跟闭包字面量。
   - 备选：只在两个闭包字面量前加 `@Sendable`，改动 2 行，但无自动化回归，后续改动容易再次漏掉。
2. 不改刷新协议、超时、文案、权限、快照 schema 或手机端回复逻辑；不停用刷新按钮来掩盖崩溃。
3. 与 `2026-10-24-phone-care-layout` 合并构建 2406，同包覆盖安装两端，不卸载、不清缓存、不开 iCloud。

## Architecture
Watch 按钮 → `WatchBridge.requestRefresh()`（MainActor）→ `WCSession.sendMessage(msg, replyHandler: handlers.reply, errorHandler: handlers.failure)` → [WC 后台队列] `WatchRefreshHandlers` 解码 → `Task { @MainActor }` → `WatchBridge` 更新 `refreshState` / `status` / `accept(snapshot)`。

## Risks / Trade-offs
| 风险 | 缓解措施 |
|------|----------|
| 平台 WC 回调无法在单元测试中复现 | Core 测试从后台队列调用 handler 验证主线程交付与结果分支（RED 为类型缺失的编译失败，不是复现 trap）；真机崩溃报告作为平台 RED，修后真机复验 + 崩溃目录无新增作为 GREEN；check.sh 守卫防止调用点回退 |
| `[String: Any]` 非 Sendable | 只在回调队列内读取 `Data`（Sendable）后跨 actor |
| 「切页退出」另有原因 | 修复后真机切页与刷新分别复验；有新报告则另立变更 |
| 编译器诊断变化（Swift 6 严格并发） | 双端构建全绿为门禁 |
