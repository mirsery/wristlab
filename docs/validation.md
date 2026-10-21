# 验证与范围 / Validation scope

## 已执行的逻辑验证

原main基线：30个核心测试与1个工作区测试通过；核心测试包含循环核对12组spec数值金例。对应应用源码的[CI运行](https://github.com/mirsery/wristlab/actions/runs/39454777037)已通过。

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

CI执行`./scripts/check.sh`和`./scripts/build-apple.sh`，构建iPhone、Watch及Widget目标；截图来自运行的双端模拟器合成演示。[已通过的构建与截图运行](https://github.com/mirsery/wristlab/actions/runs/39454777037)同时记录于截图manifest；后续仅文档更新可复用指纹一致的截图。

此前本机仅有Command Line Tools，通过`scripts/swift-test.sh`显式发现已安装的TestingMacros插件，已能执行全部领域测试；没有绕过断言。

## 真机待验收

当前开发Mac已安装Xcode27.1，iPhone真机签名、安装与启动已通过；以下能力仍未验证：

- Apple健康真实授权、历史与增量/删除送达。
- 锁屏文件保护、系统后台执行机会和撤销读取后的可读变化。
- 配对Watch快照送达、断连重连、producer更换和离线清除。
- App Group与表盘组件安装/刷新、无障碍实机体验。

代码与模拟器可验证的部分完成后，仍需按H-001/H-005/H-007及P-004/P-005用真机补验。公开验证记录只写系统版本和结果，不上传真实健康数值。

## 表盘扩展：2026-10-21 本地 Build 验证

本轮新增7个Swift Testing测试函数，37个核心测试通过（参数化URL用例覆盖多个输入）；工作区测试及最终回归结果在STDD test-report记录。新增显示状态、真实零、按指标严格失效边界、损坏/清除/演示缓存隔离、预排时间线和URL白名单测试。两端图标为同一已确认母版的1024平方不透明导出；本机iPhone/Watch/Widget编译通过。

说明页已在双端模拟器观察并保存[实际截图](screenshots/watch-face/README.md)。当前watchOS27模拟器的simctl openurl返回LSApplicationWorkspaceErrorDomain 115；这不能当作路由成功证据，也不单凭该错误断言实际Widget点击失败。四组件实际安装、各family外观和冷/热点击仍待平台验收。完整17项TC对照见[本轮测试报告](../.stdd/changes/2026-10-21-watch-face-complications/test-report.md)。

真实设备架构未签名构建也已通过。已接入iPhone；通过Xcode现有个人团队生成开发证书和匹配的App Group/HealthKit profiles后，三目标真机签名构建通过。用户开启开发者模式并信任开发者后，针对设备更新profile，iPhone16ProMax/iOS27.2的安装、普通启动与进程运行查询通过（0.1.0/1）。Watch实际安装及HealthKit授权仍未验证。
