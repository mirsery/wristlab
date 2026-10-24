# iPhone 五 Tab 与已有健康数据展示

<!-- source_hash: e64a27305c503300 -->
<!-- generated_at: 2026-10-22T11:39:58.139318 -->
<!-- canonical: canonical/proposals/2026-10-22-phone-tabs.yaml -->

## Why

首页串联全部内容，阅读路径过长，已有数据未充分展开。

## What Changes

- 今天、睡眠、活动、趋势、我的五个底部Tab，独立导航并保留会话内浏览位置。
- 今天仅三项估算和睡眠、活动摘要，详情移至主题页。
- 展开已有睡眠、活动负荷、运动记录、覆盖度、7/30日历史、个人基线和心情。
- 我的集中健康连接、来源、校准进度、更新时间及现有设置。

### New Capabilities

- **phone-tabs**：五Tab及独立浏览状态

### Modified Capabilities

- **phone-health-content**：已有健康报告的主题化展示

## Success Criteria

- [ ] 默认今天，五Tab固定可达；会话内保留详情路径、滚动位置和趋势筛选。
- [ ] 今天仅核心状态和主题摘要，完整曲线、历史和心情移入主题页。
- [ ] 四个主题页充分展示已有数据，所有设置操作可达。
- [ ] 空数据、校准、过期、演示、大字体及VoiceOver均有验收。
- [ ] 执行check.sh及Apple构建，模拟器和真机验证分开报告。
