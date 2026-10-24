# Gate 2前自审

需求覆盖：C1本地读取/事务→WI-L；C2/C3来源选择与组件→WI-S；C4设置/清除/迁移→两组场景。2 requirements、10 scenarios、10唯一P0 TC；置信度7高3中。全部THEN为SHALL，AND不超过限制。

锚定：cross_system=true要求至少L2；proposal为L2，参考当前HealthRepository/SnapshotReceiver/WatchSnapshotDelivery，保留snapshot-v1通道，锁定分区、模式及清除权威。

修正：普通展示失败保留旧显示不适用于停止清除隐私操作，已明确停止标记先落盘、仓库清理失败重启仍不读不显示旧本地数据。升级缺包与损坏包区分，防止清除后回退旧缓存。新旧phone模式兼容，手机clear只作用手机副本并更新用户确认范围。

结构：设计、两份Human View/Canonical规格、两份agent规格、测试计划齐全；CLI validate、project-check和git diff --check通过。canon单change渲染限制，Human View按YAML整理，Gate 2批准时由CLI重新生成。经验CLI缺requests，手动参考EXP-20261023-009；不声称经验CLI已完成。

当前只有设计与草案spec，不运行产品测试或构建，不改变app代码，不安装设备。Gate 2未确认，不进入Build。
