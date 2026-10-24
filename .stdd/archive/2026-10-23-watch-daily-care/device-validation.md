# 2401真机验证与发现（2026-10-24）

用户在本地交付后另行要求“真机验证下呢”，据此恢复本次设备签名/同包覆盖/普通启动，不沿用上次禁止真机的执行边界。没有卸载/清数据、开启iCloud或导出健康记录。

当前源码generic iOS连内嵌Watch/两组件签名构建成功，四包版本2401、bundle/App Group/HealthKit与无云entitlement验证通过（work/watch-care-device-build.log、watch-care-device-signing.log）。手机安装回执sequence2172，手表sequence992；均再次查询0.1.0（2401）确认新版存在。手表最初开发通道超时后恢复。两端初次launch因Locked失败，用户确认解锁后两端普通launch回执成功。

launch回执不等于稳定运行：后续手表进程只见Widget，用户明确反馈“手表闪退”。定向控制台过滤异常元数据，复现NSInvalidArgumentException：Date components require a calendar，退出1。只读取崩溃报告文件名/时间，没有复制报告或健康数据容器。已新建[calendar修复变更](../2026-10-24-watch-activity-calendar-crash/design.md)，Gate1/2均由用户实际确认；2401不记为功能通过。

手机曾核对普通主进程可启动，用户实际反馈“无数据，刷新已取消”，再次点“连接 Apple 健康”无反应。尚不能断言拒绝授权或已读到健康数据，另诊断；不将手机读取、Watch真实活动/表盘/滚动验收标为通过。

后续修复的最终设备结果：Watch2402已实际同包覆盖、版本/普通启动及延迟主进程确认，用户回复“不再闪退，页面可打开”。手机独立PHC修复迭代到2404，实际安装核对后用户从设置入口回复“已更新本地报告”。这是本轮关键故障反馈，不追认原2401可用，也不证明所有活动/表盘/后台/性能验收通过；两份修复报告另行Gate3确认。

最终两份修复报告已获用户“确认，本轮修复验收并本地归档”，Gate3与本地交付完成；[Watch修复交付](../2026-10-24-watch-activity-calendar-crash/delivery.md)及[手机修复交付](../2026-10-24-phone-health-connection/delivery.md)保留真实确认与未验项。原日常关怀功能的所有平台场景仍未被本次两个故障修复追认为完整验收。
