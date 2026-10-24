# Spec: watch-local-health

> Change: 2026-10-23-watch-independent | Auto-generated Human View

## Requirements

### Requirement: WI-L：主动授权、独立本地仓库及同核心报告。

#### Scenario: WI-L-001

- **GIVEN** 手机不可达，用户主动选择手表本地
- **WHEN** 在Watch发起健康授权并刷新
- **THEN** SHALL 只请求五类既有只读类型，在Watch读取/计算/保存，不等待手机；空查询不判拒绝。

#### Scenario: WI-L-002

- **GIVEN** 输入不足或合成输入与手机完全相同
- **WHEN** 同asOf及profile执行原引擎
- **THEN** SHALL 不改变公式/14有效日门槛；同输入结果一致，不足显示实际X/14及对应原因，不补演示。

#### Scenario: WI-L-003

- **GIVEN** 无本地profile或用户修改本地设置
- **WHEN** 连接健康前确认默认值或修改时区/睡眠目标/maxHR/训练模式
- **THEN** SHALL 显示独立设置来源；默认时区固定、8小时、maxHR未知及maintain，修改原子重算且推进epoch，不自动继承手机。

#### Scenario: WI-L-004

- **GIVEN** 本地读取进行中或晚到结果待提交
- **WHEN** 用户确认停止手表读取并清除本地数据
- **THEN** SHALL 停任务并清本地记录/anchors/报告，保留清除控制信息，不删除Apple健康或手机副本，不自动切来源；晚回调不能复活，重启仍需主动连接。

#### Scenario: WI-L-005

- **GIVEN** 查询/保存失败、相同sample删除或重复、锁屏、演示记录
- **WHEN** 尝试提交本地报告
- **THEN** SHALL 保留旧事务/anchor且明确失败，不让演示落真实仓库；正常去重/删除及取消遵循003，前台有界批次而不常驻后台。
