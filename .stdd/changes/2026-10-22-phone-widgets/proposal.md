# iPhone主屏与锁屏小组件

<!-- source_hash: c88ed8fe54fbcf2f -->
<!-- generated_at: 2026-10-22T02:26:25.538042 -->
<!-- canonical: canonical/proposals/2026-10-22-phone-widgets.yaml -->

## Why

iPhone上只能打开应用才能看到准备度、电量与压力；同类产品普遍提供主屏/锁屏小组件。

## What Changes

- iPhone应用每次得到真实（非演示）快照后，原子写入iPhone App Group中的phone-snapshot.json并请求重载小组件；清除数据写入清除标记。
- 新增iPhone小组件扩展：一个“Wristlab状态”配置，支持主屏小/中尺寸与锁屏圆形（准备度）、矩形（三项）、行内；缺失/过期/等待/已清除状态沿用ComplicationPresentation；固定本地化名称。
- Core新增从快照文件解码的校验入口（演示、损坏、超限、未知schema拒绝；清除标记保留）；组件时间线在各指标失效时刻刷新。
- 组件注册运行检查扩展到iPhone小组件配置；CI超时上限按新增步骤调整。

### New Capabilities

- **phone-widgets**：iPhone快照缓存、小组件配置与显示（C1–C4）

## Success Criteria

- [ ] 快照文件解码拒绝演示/损坏/超限/未知schema并保留清除标记，有单测。
- [ ] iPhone小组件配置在注册运行检查中逐个执行成功。
- [ ] check.sh与build-apple.sh通过；模拟器小组件渲染截图检查；真机添加与刷新由用户验收。
