# Spec: watch-sync

> Change: 2026-10-23-watch-refresh-handshake | Auto-generated Human View

## Requirements

### Requirement: H-007：刷新请求回执与快照实际接收分别确认。

#### Scenario: SC-001

- **GIVEN** 无快照且手机不可达或激活失败
- **WHEN** 请求刷新
- **THEN** SHALL 展示连接原因而非已收到数据，保留旧缓存。

#### Scenario: SC-002

- **GIVEN** 手机可达且有合法真实快照
- **WHEN** 手表请求刷新
- **THEN** SHALL 交付已有快照并尝试刷新；仅校验落盘成功才显示收到。

#### Scenario: SC-003

- **GIVEN** 手机收到请求但无快照、未连接健康或刷新失败
- **WHEN** 手机处理请求
- **THEN** SHALL 回传明确无值原因；不以空快照或演示伪装成功。

#### Scenario: SC-004

- **GIVEN** 旧手机无回执，或重复点击、迟到回复
- **WHEN** 请求后等待15秒或收到迟到结果
- **THEN** SHALL 有界结束等待、合并并发请求并隔离旧回复；原context仍可接收。

#### Scenario: SC-005

- **GIVEN** 清除标记、旧revision、新producer或落盘失败
- **WHEN** 经回复或context接收快照
- **THEN** SHALL 统一经过既有接收规则，不绕过确认、不复活已清数据、不误报保存成功。
