# 验证与范围 / Validation scope

## 已执行的逻辑验证

本地最新运行：30个核心测试与1个工作区测试通过；核心测试包含循环核对12组spec数值金例。CI最终revision的运行链接在PR中记录。

`Packages/WristlabCore/Tests/WristlabCoreTests/BusinessTests.swift`通过公共API覆盖：

- SCN-001/002/003：基线13/14日、常量历史尺度、准备度数值。
- SCN-006：压力完整/仅HR两条公式；12组JSON金例覆盖readiness、stress、batteryStep、exertion、targetRange、sleepDebt、regularity。
- SCN-009/011/012：分钟积分、30分钟与超30分钟缺口，以及确定性重放。
- SCN-014/015/018/019：卧床与分期不重算、无asleep不编造、债务缺失及跨午夜规律性。
- SCN-020/021/022/025：DST23/25小时、负荷映射/分区和目标历史缺失。
- SCN-027/028/029：旧epoch拒绝、清除不复活、空输入不出分数。
- 本地事务重开、anchor和报告同批持久化、磁盘失败回滚、旧任务revision拒绝、sample版本不回退、未变内容不刷新快照及非法缓存分数显示保护。
- 23日合成记录到完整报告；输入乱序得到相同结果。

此列表是实际测试覆盖记录，不声称全部47项验收或31个场景已全部完成。BoundaryTests还覆盖SCN-004/005夜间/日间隔离、SCN-010运动优先、SCN-016/017睡眠段与小睡、SCN-023/024去重和稀疏HR、SCN-030选源/新producer/未知schema/非法值、SCN-013/031删除重算与清除持久化。后续新增边界测试在此扩展；以源代码和CI结果为证据。

## 平台验证

CI执行`./scripts/check.sh`和`./scripts/build-apple.sh`，构建iPhone、Watch及Widget目标；截图来自运行的双端模拟器合成演示。最终run链接随PR提供。

本机只有Command Line Tools，但通过`scripts/swift-test.sh`显式发现已安装的TestingMacros插件，已能执行全部领域测试；没有绕过断言。

## 真机待验收

当前开发Mac尚未安装完整Xcode、尚未配置真机签名，以下能力未验证：

- Apple健康真实授权、历史与增量/删除送达。
- 锁屏文件保护、系统后台执行机会和撤销读取后的可读变化。
- 配对Watch快照送达、断连重连、producer更换和离线清除。
- App Group与表盘组件安装/刷新、无障碍实机体验。

代码与模拟器可验证的部分完成后，仍需按H-001/H-005/H-007及P-004/P-005用真机补验。公开验证记录只写系统版本和结果，不上传真实健康数值。
