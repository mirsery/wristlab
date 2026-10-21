# Spec: energy-complication

> Change: 2026-10-21-watch-face-complications | Auto-generated Human View

## Requirements

### Requirement: 兼容已有电量组件和同步契约

#### Scenario: SC-ENERGY-001

- **GIVEN** 用户已有WristlabEnergy组件及既有SnapshotReceiver缓存
- **WHEN** 升级应用或收到新快照
- **THEN** SHALL 保留原kind和App Group文件/schema；仍经验证的SnapshotReceiver使用epoch/sequence及新producer确认规则，清除后请求重载组件

#### Scenario: SC-ENERGY-002

- **GIVEN** 手机离线且缓存随时间变旧
- **WHEN** 用户抬腕或点击组件
- **THEN** SHALL 只按已缓存数据及时效显示，不制造实时状态；离线清除要在实际送达后生效，并继续注明真机同步/后台刷新待验收
