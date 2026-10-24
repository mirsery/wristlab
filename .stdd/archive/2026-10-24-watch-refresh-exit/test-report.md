# Watch 刷新退出修复验证报告（待 Gate 3）

日期：2026-10-24。范围 WRX-001–003。未提交、未推送。

## 根因与行为变化
2405 两份一致的崩溃报告符号化为 `closure #2 in WatchBridge.requestRefresh()` → `_dispatch_assert_queue_fail`（EXC_BREAKPOINT，WC 后台队列）。修复后 reply/error 处理由 Core `WatchRefreshHandlers` 以非隔离 `@Sendable` 闭包承接，再回主线程；协议、状态机、15 秒超时、文案不变。

## 实际检查
| 检查 | 结果 | 证据 |
|------|------|------|
| 平台 RED | 真机 2405 两份崩溃报告，UUID 匹配本地 2405 dylib 符号化 | work/watch-exit-crash/（gitignored，不入库） |
| Core RED/GREEN | 类型缺失编译失败 → 2 项通过（后台队列交付、无效/错误分支、5 秒超时不挂起） | work/watch-exit-core-red.log, watch-exit-core-green2.log |
| 调用点守卫 | check.sh grep 拦截 `replyHandler:/errorHandler:` 后的闭包字面量；样例输入验证命中 | scripts/check.sh |
| scripts/check.sh | 256 项通过 | work/fix-2406-check2.log |
| scripts/build-apple.sh | 退出 0（双端构建） | work/fix-2406-apple.log |
| 真机 | 2406 同包覆盖手表，版本 2406；手表锁屏致自动启动被拒，由用户手动打开；用户反馈「手表不闪退了」；手机代理目录与手表目录均无新增 WristlabWatch 崩溃报告 | work/fix-2406-watch-install.log, watch-exit-crash/baseline-before-2406.txt, after-2406.txt |

## TC 追溯
| TC | 测试 |
|----|------|
| TC-WRX-001 | replyFromBackgroundQueueReachesMainActor_TC_WRX_001 |
| TC-WRX-002 | invalidRepliesAndErrorsReachMainActor_TC_WRX_002 |
| TC-WRX-003 | 真机：用户反馈 + 崩溃目录对比 |

## 评审
代码评审：无 P0/P1，行为与原分支一致，`[weak self]` 不丢结果（WatchBridge 为进程级 StateObject）。测试评审 P1：Core 测试拦不住调用点回退 → 已加 check.sh 守卫；P2 挂起风险 → 改 AsyncStream+超时。文档评审：API 名称与验证表述已同步。

## 未验项
- 「切页退出」无对应崩溃报告；用户本轮反馈不再闪退，未单独区分切页与刷新。
- 手表崩溃报告同步到手机有延迟，本次对比只代表当时状态。
- 手机端异常回复（unreadable/undelivered）路径未在真机构造。
