# 设计调整

1. API 形态：设计稿写作 `WatchRefreshHandlers.make` / `handlers.error`，实现为 `WatchRefreshHandlers(requestID:deliver:)` 与 `.failure`；语义不变，文档已同步。
2. 新增 `scripts/check.sh` grep 守卫，禁止 `Apps/` 中 `replyHandler:` / `errorHandler:` 后紧跟闭包字面量。原因：Core 测试只保护工厂本身，`@preconcurrency import` 下调用点回退不会产生编译告警（测试评审 P1）。
3. Core 测试改为 AsyncStream + 5 秒超时，丢失回调记为失败而不是挂起测试进程（测试评审 P2）。
4. proposal 将 watch-runtime-stability 标为 Modified，但 `.stdd/specs/` 中尚无该能力；归档时按新能力登记。
