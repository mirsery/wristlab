# Watch活动摘要日期契约闪退修复

<!-- source_hash: af3fc4f811d7e0e5 -->
<!-- generated_at: 2026-10-24T03:12:51.211101 -->
<!-- canonical: canonical/proposals/2026-10-24-watch-activity-calendar-crash.yaml -->

## Why

用户真机2401版Watch闪退，目标进程复现NSInvalidArgumentException：Date components require a calendar。当前活动摘要参数只有era/year/month/day，未携calendar。

## What Changes

- 提取生产活动摘要日期构造并明确携Gregorian calendar与系统时区，保持原系统日归属。
- 生产适配器参数通过真实HealthKit谓词构造回归，包含近午夜/纽约DST合成日期；同包2402复验。

### Modified Capabilities

- **watch-daily-activity**：修复WDA活动摘要日期契约，不改读取类型/写权限/系统日/评分或存储。

## Success Criteria

- [ ] 真实HealthKit谓词在原日期参数下RED复现同一calendar异常。
- [ ] 修后生产日期构造在UTC/上海/纽约及DST与近午夜合成输入下构造谓词成功，日期归属不变。
- [ ] 全部回归与Apple构建通过；真机同包更新后单独验证不再同因闪退，用户反馈与未验项分开记录。
