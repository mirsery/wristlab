# Watch 首次同步与刷新回执排障

<!-- source_hash: 5c932d3d4c751afc -->
<!-- generated_at: 2026-10-23T16:25:11.339677 -->
<!-- canonical: canonical/proposals/2026-10-23-watch-refresh-handshake.yaml -->

## Why

实体Watch被系统识别，但没有快照。请求刷新后显示已请求手机刷新；该状态在发送前赋值，不能证明手机收到或完成处理。根因尚待验证。


## What Changes

- 建立不含健康值的请求回执与快照接收诊断闭环，区分不可达、等待回执、刷新失败和无快照。
- 依据复现修复首次同步或刷新响应，保留缓存、清除标记、演示隔离及旧协议兼容。

### New Capabilities

- **refresh-diagnostics**：手机处理结果与手表实际收到快照分别确认。

### Modified Capabilities

- **watch-sync**：H-007 双端同步及首次快照交付。

## Success Criteria

- [ ] 失败与无快照原因可区分，不把发送请求当成同步成功。
- [ ] 手机已有真实快照时，真机手表主动刷新可展示同revision；断连不伪造数据。
