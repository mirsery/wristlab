# 单切片 S1

依赖：WristlabCore `WatchRefreshReply`（已有）→ 新增 `WatchRefreshHandlers` → `WatchBridge.requestRefresh()` 接入。无循环。标准模式；2 个 TC 自动化（Core Swift Testing），WRX-003 需真机。

先写 Core 后台队列测试（类型缺失编译失败为 RED，平台 RED 为两份已符号化的 2405 崩溃报告），再实现非隔离 `@Sendable` handler 工厂并接入 WatchBridge；原刷新状态机、文案与超时不变。
