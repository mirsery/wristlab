# S1 手机连接与读取任务的完整生命周期

依赖：生产DashboardModel→原HealthKitReader/HealthRepository；无新增跨能力依赖与循环。一个连贯切片覆盖PHC001至006控制流及007设备交付；不能将007手工验收算成单测通过。复杂度7，standard，中风险；L2接口锚定原模型和仓库。

依据：授权等待与取消路径已经两个生产模型诊断RED；初始化提取原缓存路径、适配器及通知清理接缝，不改正式默认业务；10个合成测试先RED→修复GREEN，再补旧运动重读RED与竞争保护，总14函数GREEN。三路只读技术评审及晚回调测试补强已通过复核，之后全量check.sh、Apple构建及2403同包手机验收。Watch开发连接仍独立阻塞，不新增权限/数据迁移。

CLI dependency-graph已执行；structure delta仍默认错误根目录，experience缺requests，手工参考EXP011/012并保留日志，不改上游、不安装额外依赖。没有SwiftLint/coverage配置，不新增工具或伪造coverage。

# S2 设置弹层就近反馈补漏

用户2403设备反馈定位到设置入口，原14个控制器测试不能证明设置弹层的可见反馈。沿用原Gate1/2连接状态修复范围，PHC001加明确入口可见性条件，PHC007继续设备待验；不新增能力或权限。新增4个真正点击生产SettingsView的iOS XCTest UI函数，先原设置RED，再最小补反馈GREEN并纳入build-apple.sh。生产设置和模型原样编译，只有HealthKit/同步/表盘导航替身及合成测试工具条，禁止把此宿主当真实健康或整App E2E通过。
