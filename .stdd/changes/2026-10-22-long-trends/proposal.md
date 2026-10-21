# 长期趋势、个人基线区间与近7日回顾

<!-- source_hash: eac1507ec53eac46 -->
<!-- generated_at: 2026-10-22T02:11:11.790464 -->
<!-- canonical: canonical/proposals/2026-10-22-long-trends.yaml -->

## Why

趋势只有7日，看不出几周的走向；夜间HRV与静息心率是准备度的输入，却没有逐日展示，也没有个人常态范围可对照；没有本周与过去几周的比较。

## What Changes

- 报告7日history扩展为35日；DayOverview新增可选nightHRV（主睡眠内有效HRV至少2条时的中位数）与restingHeartRate（当日静息心率）。
- 报告新增可选personalRanges（个人基线区间）：仅当今天准备度为夜间模式时，用与今天准备度完全相同的夜间基线（前60个分析日、今天主睡眠来源、至少14个有效夜晚）给出|z|<0.5对应的HRV与静息心率区间；否则为nil。
- 趋势支持7/30日切换，指标增加夜间HRV与静息心率；HRV/静息心率图叠加个人常态范围带；缺失日留白。
- 新增近7日回顾：近7日（含今天）与此前28日在准备度、睡眠、夜间HRV、静息心率上的均值、有效天数与差值；有效天不足时显示记录不足，不下因果结论。

### New Capabilities

- **long-trends**：35日逐日历史、个人常态范围与7/30日趋势（C1–C3）
- **weekly-review**：本周与前4周对比（C4）

## Success Criteria

- [ ] 引擎输出35日history，含逐日夜间HRV与静息心率；准备度、压力、电量数值与改动前一致。
- [ ] 个人常态范围等于准备度基线中位数±0.5尺度（HRV按对数）；不足14日为nil。
- [ ] TrendSeries支持30日与HRV/静息心率，缺失日为nil。
- [ ] 周回顾均值、有效天数门槛与差值有单测；不足时为nil。
- [ ] 旧缓存JSON缺新字段可解码；check.sh与build-apple.sh通过；模拟器截图视觉检查；真机由用户验收。
