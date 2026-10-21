<div align="center">

# Wristlab

<img src="docs/brand/icon-master.png" width="88" alt="Wristlab app icon" />

**把状态看清楚。**

一个本地优先的 iPhone + Apple Watch 私人健康趋势实验室。

[English](README.en.md) · [业务规格](specs/README.md) · [开发指南](docs/development.md) · [验证记录](docs/validation.md)

![CI](https://github.com/mirsery/wristlab/actions/workflows/ci.yml/badge.svg)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/iOS-17%2B%20%7C%20watchOS%2010%2B-222)
![License](https://img.shields.io/badge/License-MIT-8DEDB6)

</div>

## 界面预览

<table align="center">
<tr><th>iPhone · 今日报告</th><th>Apple Watch · 抬腕查看</th></tr>
<tr>
<td valign="top"><img src="docs/screenshots/iphone.png" width="300" alt="iPhone · synthetic demo data" /></td>
<td valign="top"><img src="docs/screenshots/watch.png" width="180" alt="Apple Watch · synthetic demo data" /></td>
</tr>
</table>

截图由 CI 在实际运行的 SwiftUI 应用中通过 `--demo` 生成，使用合成健康记录，与真实模式共用业务引擎。不是概念图，也不包含真实健康数据。设备与生成来源见 [截图说明](docs/screenshots/README.md)。

## 能做什么

| 功能 | 业务行为 |
| --- | --- |
| 训练准备度 | 60日个人历史、至少14个有效日；夜间优先，必要时明确回退日间估算 |
| 生理压力 | 5分钟桶，睡眠/清醒基线隔离；HRV缺失时标注仅依据心率 |
| 身体电量 | 睡眠充电、活动耗电、跨日连续；缺口和重新校准明确可见 |
| 睡眠 | 单来源解析、分期去重、主睡眠/小睡、7日睡眠债与入睡规律性 |
| 运动 | 只读已有训练，HRR心率分区、已观测负荷、体能输出与历史参考区间 |
| 数据解释 | 缺失原因、基线数量、部分质量、覆盖度、版本和更新时间 |
| 双端体验 | 手机报告与趋势；手表快照；电量/准备度/压力及总览表盘组件 |
| 本地控制 | 选源、固定分析时区、目标设置、清缓存/停止读取、离线清除标记 |

真实模式默认空状态，用户主动连接 Apple 健康后读取。演示需要主动进入，始终标识合成数据，不写入真实同步缓存。

## 运行

需要安装完整 **Xcode**（CI使用16.4），并安装iOS/watchOS平台组件；还需[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
git clone https://github.com/mirsery/wristlab.git
cd wristlab
brew install xcodegen
./scripts/check.sh
./scripts/build-apple.sh
open Wristlab.xcodeproj
```

在Xcode为iPhone、Watch及Widget三个target选择自己的签名team。真机需配对设备、开发者模式，以及支持HealthKit、App Groups和相关entitlements的签名配置。修改bundle ID时同步修改Watch companion ID及App Group标识；详见[真机指南](docs/development.md)。

模拟器想直接看演示，可在scheme的启动参数加入 `--demo`。普通启动不会自动创建健康分数。

## 数据与算法

健康记录在设备本地处理和存储，采用文件保护与原子提交。没有后端、广告/统计SDK、账号、订阅或AI上传。Watch只接收最小展示快照，不接收原始心率序列。

准备度、压力和电量是公开版本化的**实验性估算**，不是直接测量，不用于医疗判断或训练处方。本项目以PeakWatch公开业务行为为参考，使用原创名称、界面和代码；与PeakWatch无关联，未使用其私有算法，也不保证分数相同。HRV v1使用**SDNN**，不会称为RMSSD。[参考证据和差异](specs/000-reference-behavior.md)

保守的数据门槛会使部分指标暂时为空：没有主睡眠不初始化电量；连续缺口超过30分钟会断链；日负荷覆盖不足不生成完整日参考目标。这些都不会被演示值或默认正常分数替代。

## 架构与验证

```text
HealthKit增量 → 规范记录/来源 → 睡眠与个人基线
                              → 准备度/压力/负荷 → 电量重放
                              → 原子本地报告 → 手机 / Watch / 组件
```

- `Packages/WristlabCore`：纯Swift领域计算、报告、事务存储与同步协议。
- `Apps/iOS`：只读HealthKit适配、设置、报告、图表和解释。
- `Apps/watchOS`：快照显示、刷新请求、新手机确认和演示。
- `Apps/Widgets`：WidgetKit三指标与总览组件。
- `project.yml`：工程源配置；生成的Xcode工程不提交。

CI验证规格结构、领域测试及双端模拟器构建，并生成截图。12组数值金例来自spec；更多边界和端到端用例见[验证记录](docs/validation.md)。**模拟器构建与截图不等于真机HealthKit、后台调度、签名或组件安装通过。**

尚未包含AI、饮食识别、训练课程、运动录制、云同步、商业化及上架流程。完整范围以[业务spec](specs/README.md)为准。

## 参与

先更新spec和验收，再实现/测试，使用PR合并。`main`要求两项CI检查通过，禁止强推和删除。[AGENTS.md](AGENTS.md) · [CONTRIBUTING.md](CONTRIBUTING.md) · [PRIVACY.md](PRIVACY.md)

MIT License。Issue、日志、测试和截图只提交合成数据，勿上传健康导出或签名资料。

开发流程采用 [STDD](docs/stdd.md)：Spec + Test 驱动、四阶段与三道确认 Gate。项目初始化命令入口为 `./scripts/stdd`。

## Apple Watch 表盘

手机“设置 → Apple Watch → 表盘组件”及手表“更多 → 表盘组件”中有添加步骤和明确标注的合成预览。单项电量、准备度、压力支持圆形、矩形、行内与角落槽位；状态总览使用矩形槽位。具体可用项由系统表盘决定。

真实组件只显示手机同步快照，缺失/校准/过期不补默认分数，过期值显示破折号。点击单项打开对应报告；总览打开Watch首页，外部组件入口退出演示。系统决定刷新预算，不承诺实时刷新。尚无打包好的.watchface预设文件，使用系统表盘编辑器添加。

本轮已通过本机编译和纯逻辑测试；实际表盘安装/冷热点击及系统刷新以[验证记录](docs/validation.md)为准，不以应用内示意预览代替验收。

[本轮表盘说明页实际截图](docs/screenshots/watch-face/README.md)（合成预览，非系统表盘截图）。
