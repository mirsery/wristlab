# Wristlab 表盘组件与已确认图标接入

<!-- source_hash: 540c92e5d26ca510 -->
<!-- generated_at: 2026-10-21T11:31:42.831852 -->
<!-- canonical: canonical/proposals/2026-10-21-watch-face-complications.yaml -->

## Why

当前仅有身体电量组件骨架，缺少准备度、压力、组合展示及安装引导；用户已确认原创图标，并要求接入表盘功能。

## What Changes

- 接入已确认的薄荷绿W图标，生成iPhone和Watch应用图标资源及构建配置。
- 保留既有身体电量组件标识，补齐训练准备度、压力组件；按槽位支持圆形、矩形、行内与角落布局。
- 新增矩形三指标总览组件；点击组件打开Watch应用并定位对应指标或总览。
- 在手机和Watch提供表盘设置引导与可见的预览，说明如何在系统表盘编辑器中选择Wristlab组件。
- 统一组件的缺失、校准、部分质量、过期和清除状态；过期数值不作为当前值显示，读取同一App Group快照。

### New Capabilities

- **watch-face-metrics**：三种单指标及三指标总览布局、组件深链和安装引导。

### Modified Capabilities

- **energy-complication**：保留已有kind并统一过期和缺失表现。
- **app-identity**：使用用户已确认原创图标。

## Success Criteria

- [ ] 已确认图标进入两个应用的图标目录，iPhone/Watch/Widget构建通过。
- [ ] 系统可枚举电量、准备度、压力与总览组件；既有电量kind保持不变。
- [ ] 组件点击能打开对应Watch页面，无效URL安全回退。
- [ ] 合成测试覆盖新鲜、过期、空、清除和校准等显示状态；不把缺失值当作0或健康分数。
- [ ] 手机与手表均能打开表盘设置说明；双语README及验证记录同步。
- [ ] 保留真机签名、实际表盘安装及系统刷新待验收状态，模拟器截图不替代真机结论。
