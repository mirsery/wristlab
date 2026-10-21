# 十四类失败模式检查

2026-10-21，按上游experience.py类别逐项审阅当前diff与执行证据。检查完成不等于所有产品验收通过。

| 类别 | 结果与证据 |
| --- | --- |
| a 幻觉行为 | 已查：37 Core +1 workspace实际测试与两次模拟器BUILD SUCCEEDED；未将说明页预览写作实际表盘截图。 |
| b 范围蔓延 | 已查：对照Canonical三capability，评分/HealthKit/同步schema无变更；新增原始图标与Widget/说明属于批准范围。 |
| c 级联错误 | 已查：共同显示模型被Widget和真实Watch页复用；原30 Core测试无回归。 |
| d 上下文丢失 | 已查：Gate1/2原文保留在CLI状态；Gate3未批准；本报告与phase-context记录实际剩余项。 |
| e 工具误用 | 发现并记录：上游CLI按旧目录及Python测试扫描导致0/17误报，保留原日志、不修改上游/伪报通过。 |
| f 运行时偏差 | 部分未关闭：说明页实际运行；Watch simctl openurl返回LSApplicationWorkspaceErrorDomain 115，未证明Widget点击成功。系统表盘与真机验收待执行。 |
| g 管线断链 | 已查：check.sh通过，iOS+watchOS+内嵌Widget构建成功；CI独立状态由PR检查报告，不把本地通过等同CI。 |
| h 内容质量偏差 | 已查：双语README、独立合成预览标签、图片来源说明；docs链接检查通过。 |
| i 指令衰减 | 已查：无健康导出/签名材料提交；无自动Gate3、merge、archive或社区发布。 |
| j 覆盖真空 | 部分未关闭：7新增测试覆盖12个TC的纯逻辑部分；17个TC完整矩阵见报告。代码覆盖率配置禁用，SKIPPED，未报百分比。 |
| k 契约断层 | 已查：现有kind、group、文件名与schema保留；SnapshotReceiver严格协议测试回归；时间线边界和无缓存状态新增测试通过。 |
| l 锚定缺失 | 已查：Canonical proposal的L2锚定指向原Widget、WatchBridge、spec003；复用这些接口。上游CLI旧路径跳过不替代人工核对。 |
| m Agent CP失败 | 已查：三个独立评审均返回，发现演示路由/过期首页/启动参数竞态均已处置；外部agent verify管道未启用，SKIPPED。 |
| n 跨系统不一致 | 部分未关闭：Widget/Watch共用显示/URL模型与现有接收协议；iPhone+Watch真实送达/清除及后台刷新待真机验证。 |

补查spec歧义：等于失效边界仍有效，严格大于隐藏；真实0与缺失区分；固定四kind与布局边界均已明确。系统刷新时机不承诺。

CLI确定性子集：5通过、4跳过、1错误（TC扫描0/17）。真实Swift测试位于Packages/WristlabCore/Tests，已逐个对照TC注释和断言；平台TC没有因注释存在而计为自动通过。经验条目EXP-20261021-001记录显示/导航一致性陷阱。
