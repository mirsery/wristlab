# Watch 刷新退出测试方案

> 创建日期：2026-10-24 · 对应 Spec：specs/watch-runtime-stability/spec.md（WRX-001–003）

## 一、测试策略
平台 RED 来自真机两份一致的崩溃报告（已符号化）。自动化在 WristlabCore 用 Swift Testing 从 `DispatchQueue.global()` 调用 handler，覆盖跨线程交付与全部结果分支；真机复验覆盖 WatchConnectivity 实际回调。现有 254 项 Swift 测试（含 `WatchRefreshTests`）保留。

## 二、详细测试案例

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WRX-001 |
| 对应 Spec / 优先级 | WRX-001 / P0 |
| Arrange | 合成 requestID；`WatchRefreshReply` 编码后放入 `["refreshReply": data]` |
| Act | 后台队列调用 `handlers.reply` |
| Assert | `deliver` 在 MainActor 收到 `.reply`，requestID / outcome / snapshot 与输入一致；测试进程无 trap；5 秒内无交付记为失败而非挂起。调用点回退由 check.sh grep 守卫拦截 |

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WRX-002 |
| 对应 Spec / 优先级 | WRX-002 / P0 |
| Arrange | 四组输入：requestID 不匹配、缺 key、坏数据、合成 NSError |
| Act | 后台队列调用 reply / error handler |
| Assert | 前三组 `.unreadable`，error 组 `.undelivered`；每组恰好交付一次 |

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WRX-003 |
| 对应 Spec / 优先级 | WRX-003 / P0（手工） |
| Arrange | 2406 同包覆盖 Watch，不清数据；记录覆盖前崩溃目录清单 |
| Act | 用户点「请求手机刷新」并左右切页若干次 |
| Assert | 崩溃目录无新增 WristlabWatch 报告；手表状态显示刷新结果；用户反馈记录原话 |

## 三、测试执行矩阵
| 功能模块 | 单元 | 平台构建 | 真机 |
|----------|------|----------|------|
| reply 跨线程交付 | 001 | 双端构建 | 003 |
| 错误与无效回复 | 002 | 双端构建 | 未计划（需构造手机异常） |

## 四、回归风险矩阵
| 风险区域 | 本轮改动 | 已有回归保护 | 风险等级 |
|----------|----------|--------------|----------|
| 刷新状态机 | 不改 | WatchRefreshTests | 🟢 |
| 手机端回复 | 不改 | WatchRefreshTests | 🟢 |
| 快照接收 | 不改 | SnapshotCacheFileTests | 🟢 |
| 切页退出 | 未定位 | 真机复验 | 🟡 |

## 五、建议补充顺序
单切片：001/002 RED（类型缺失）→ Core handler 工厂 → GREEN → WatchBridge 接入 → check.sh + build-apple.sh → 2406 同包覆盖 → 003 → Gate 3 用户确认。
