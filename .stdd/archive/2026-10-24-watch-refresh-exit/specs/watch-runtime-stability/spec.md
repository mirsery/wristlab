# Spec: watch-runtime-stability

> Change: 2026-10-24-watch-refresh-exit | Auto-generated Human View

## Requirements

### Requirement: Watch 刷新回复在 WatchConnectivity 后台队列回调时不触发 MainActor 隔离检查，结果交回主线程处理。

#### Scenario: WRX-001

- **GIVEN** 一个合成 requestID 和匹配的 WatchRefreshReply 编码数据
- **WHEN** 从非主线程的后台队列调用刷新 reply handler
- **THEN** SHALL 进程不 trap，并在 MainActor 上交付 .reply，内容与原回复一致。

#### Scenario: WRX-002

- **GIVEN** requestID 不匹配、缺少 refreshReply 或数据无法解码；或 WC 调用 error handler
- **WHEN** 从后台队列调用对应 handler
- **THEN** SHALL 分别在 MainActor 上交付 .unreadable 或 .undelivered，不丢失回调、不 trap。

### Requirement: 真机 2406 刷新与切页不再退出，保留原数据与连接选择。

#### Scenario: WRX-003

- **GIVEN** Watch 同包覆盖安装 2406，保留原缓存与手机同步选择
- **WHEN** 用户点「请求手机刷新」并切换页面
- **THEN** SHALL 不再出现 WristlabWatch 新崩溃报告，状态显示刷新结果；真机结论以用户反馈和崩溃目录为准，不以安装成功或进程存在代替。
