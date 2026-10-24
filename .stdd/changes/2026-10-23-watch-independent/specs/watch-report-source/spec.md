# Spec: watch-report-source

> Change: 2026-10-23-watch-independent | Auto-generated Human View

## Requirements

### Requirement: WI-S：显式报告来源、分区缓存及一致投影。

#### Scenario: WI-S-001

- **GIVEN** 旧安装有phone receiver，新安装没有任何缓存
- **WHEN** 首次启动新版
- **THEN** SHALL 旧安装迁移手机模式及原缓存，新安装等待用户选来源，不擅自读取健康。

#### Scenario: WI-S-002

- **GIVEN** 本地模式期间断连/重连、手机新快照或模式切换时任务晚回
- **WHEN** 接收手机回复/context或用户选择模式
- **THEN** SHALL 分区校验存储，不自动切换/拼分；只有用户切换可改显示，旧generation不能覆盖当前选择。

#### Scenario: WI-S-003

- **GIVEN** 合法所选报告、缺失/过期报告或投影保存失败
- **WHEN** App或组件加载展示包
- **THEN** SHALL 消费同一原子envelope，显示生产设备、时间和缺失/过期；保存失败保留旧包，仓库成功不冒充表盘已更新，组件系统调度不承诺准点。

#### Scenario: WI-S-004

- **GIVEN** 独立记录与手机副本均存在
- **WHEN** 手机清除并送达clearData
- **THEN** SHALL 只清手机副本并明确双端清除文案；当前本地模式不被抹除，手机模式显示清除态，旧手机revision不复活。

#### Scenario: WI-S-005

- **GIVEN** 模式已持久化、展示包缺失或损坏、新producer/无效schema/演示快照
- **WHEN** 重启、迁移或接收快照
- **THEN** SHALL 正常恢复所选模式；仅首次缺包迁移旧缓存，损坏明确错误而不回退；保持producer确认及无效/demo拒绝，不混合两份revision。
