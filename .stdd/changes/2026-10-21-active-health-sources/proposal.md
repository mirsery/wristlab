# 修复历史失活来源遮挡当前健康输入

<!-- source_hash: 9d520fdc9448f883 -->
<!-- generated_at: 2026-10-21T20:02:07.849957 -->
<!-- canonical: canonical/proposals/2026-10-21-active-health-sources.yaml -->

## Why

数量选源从全部150日保留数据挑选来源，导致60日计算窗口外的历史优先来源遮挡窗口内实际可读输入。

## What Changes

- 自动选源候选须在评估日之前60个分析日至asOf间有有效样本；窗口内维持原rank和group顺序。
- 明确用户来源优先级仍优先，revision内固定来源且返回该组全部保留历史，不逐桶混源。
- 回归引擎报告、来源切换epoch和缺失/校准行为；构建、设备安装与用户验收分别记录。
- 用户追加要求：手机/Watch显示具体缺失原因、有效基线进度与操作建议；区分电量无种子原因，不改数值公式或门槛。

### Modified Capabilities

- **active-health-sources**：数量来源候选限定实际计算窗口

## Success Criteria

- [ ] 合成旧Watch仅90日前有HR、另一来源近期有HR时，引擎生成近期压力桶，不报missingHR。
- [ ] 窗口内设备优先级、显式来源偏好、来源独立及单revision不混源均有回归。
- [ ] 来源改变触发报告/快照一致重建及epoch推进；未满足14日基线时仍校准。
- [ ] Core/spec/双端构建通过；设备安装、输入可用性和用户实际显示分别验证。
