# 晨报本地通知

<!-- source_hash: 002957c26b6e0030 -->
<!-- generated_at: 2026-10-22T02:45:17.175991 -->
<!-- canonical: canonical/proposals/2026-10-22-morning-brief.yaml -->

## Why

早上需要打开应用才知道昨晚睡眠与今天准备度；同类产品（Garmin晨报、AutoSleep、Gentler Streak晨间check-in）会在醒后推送一条摘要。

## What Changes

- 设置新增“晨报通知”（默认关）与“通知中隐藏数值”（默认开）；开启时请求通知授权，拒绝时说明并保持关闭。
- Core新增MorningBrief：报告为当天、真实来源、今天已有已完成主睡眠、分析时区05:00–14:00、当天尚未发过时生成一条通知；内容为准备度（数值与分段并标日间/部分估算，或缺失原因）与主睡眠时长，隐藏数值时只提示主睡眠已汇总。
- 每次真实刷新后若满足条件则投递本地通知并记住当天已发；演示从不发送；不承诺固定时间，取决于系统后台机会与用户打开应用。

### New Capabilities

- **morning-brief**：晨报判定、内容与设置（C1–C3）

## Success Criteria

- [ ] MorningBrief判定（当天、真实、主睡眠、去重、演示）与内容（数值/分段/缺失原因/隐藏数值）有单测。
- [ ] check.sh与build-apple.sh通过；真机通知送达由用户验收。
