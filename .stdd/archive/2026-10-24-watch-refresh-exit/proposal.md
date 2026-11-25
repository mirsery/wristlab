# Watch 2405 切页或刷新后退出诊断与修复

<!-- source_hash: b1af187542652795 -->
<!-- generated_at: 2026-10-24T13:22:52.803774 -->
<!-- canonical: canonical/proposals/2026-10-24-watch-refresh-exit.yaml -->

## Why

2405 已覆盖安装并初次启动，但用户确认切页或刷新后退出；后续定向进程检查仅剩 Widget。异常类型与根因尚未确认，不能把安装成功当稳定通过。


## What Changes

- 采集不含健康数值的异常类型、退出状态及必要调用栈，定位切页/刷新崩溃路径。
- 针对已复现根因修复回归、补合成测试并同包覆盖验证；不靠停用活动或独立读取掩盖崩溃。

### Modified Capabilities

- **watch-runtime-stability**：Watch 2405 切页或刷新后退出诊断与修复

## Success Criteria

- [ ] 有明确命令与合成/平台反馈循环复现所定位故障，根因与修复方案经 Gate 2 确认后实施。
- [ ] 对应回归及双端构建通过；真机切页/刷新路径由实际用户反馈确认，不将普通启动或进程瞬时存在作为通过。
