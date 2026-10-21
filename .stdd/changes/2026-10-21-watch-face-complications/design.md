# Wristlab 表盘组件与图标 — 技术设计草案

状态：Gate 1 / Gate 2 已由用户确认；Build 已进入实现和验证，Gate 3 待用户验收。实际验证范围以 test-report.md 为准。

## Context

现有 Watch 扩展只有 StaticConfiguration 的 WristlabEnergy，支持圆形/矩形/行内，数据经 WidgetKit Provider 读取 WatchBridge 写入的 watch-receiver.json。圆形会用0构造缺失Gauge，矩形在过期时仍显示旧值；未显式配置指标URL。Watch已支持演示、手机刷新请求和快照状态。尚无应用图标目录。

沿用 specs/001 的 P-001/P-002/P-004/P-005，以及 specs/003 的 H-005/H-006/H-007。评分、HealthKit授权及SnapshotReceiver协议均保持已有权威定义。

## Decisions

### 1. 四个静态组件，保留既有kind

采用 WidgetBundle：WristlabEnergy、WristlabReadiness、WristlabStress、WristlabOverview。三个单指标提供四种family，总览只有矩形。WidgetKit系统列表让用户直接选择，不增加AppIntent配置或OS版本依赖。备选为单个可配置组件，但会增加配置和迁移成本；保留Energy标识可兼容已有表盘。

### 2. 把显示和URL规则放到纯Foundation模型

计划新增 ComplicationPresentation.swift（WristlabCore）：指标选择、显示state、可展示value?、标题、符号名、状态文字与时效，显式传入now；另提供已知目的地的URL构造/解析及失效entry时间列表。通过同一显示模型驱动不同family和总览，公共API写失败测试。Apple文件读取/WidgetKit视图保留在适配层。

显示优先级：无/无效/清除/演示缓存 → 无数值；有效快照若未来或超过60分钟 → 全部过期；否则各指标独立检查未来effectiveAt与validUntil；有效0保留；无数值时按availability显示校准/不足/不支持/失败。partial保留有效数值并标注估算。所有缺失/过期状态用破折号和符号，不以Gauge(0)假装真实零。更新时间保持原快照时刻。

### 3. 失效时间线与快照隔离

Provider继续读取现有App Group并验证SnapshotReceiver，排除clearData和demo来源。时间线包含当前和各指标/快照失效边界后一秒，排序去重；SnapshotReceiver的epoch、sequence、新producer确认及clearData规则不变。系统可能延迟更新，因此只承诺正确的entry计划及请求重载，不承诺固定刷新频率。清除实际送达后才刷新远端，手机离线不宣称已清除手表。

### 4. 点击后进入Watch指标页

仅支持 wristlab://complication/{energy,readiness,stress,overview}，无query/fragment/userInfo/port。Watch target注册URL scheme，widgetURL写入对应目的地；onOpenURL在冷启动及运行时设置导航，overview/无效URL回首页。单指标页显示同一缓存的分数/状态/更新时间并可请求手机刷新。URL不带健康值，不触发授权，不写健康数据。手机不注册该scheme，避免意外打开手机端。

### 5. 原创图标与双端说明

原母版位于 outputs/brand/wristlab-icon-approved.png，1254平方、不透明；在Build阶段用系统图像工具仅做技术尺寸导出，保留已确认图案。计划增加iOS/watchOS Assets.xcassets/AppIcon.appiconset及显式target设置；优先使用1024统一源，按本机Xcode与CI的actool实际编译结果兼容输出，不改变最低iOS17/watchOS10。Widget无需单独的启动图标。

iPhone设置与Watch更多菜单加入“表盘组件”说明页，共享说明内容和简洁的组件预览视图，明确标注合成演示。预览不进入App Group。说明用户通过系统表盘编辑器选槽位；尚无有效.watchface资源，不制作失效的一键安装按钮。

## Architecture

```text
现有手机报告 → WatchBridge → 原子App Group SnapshotReceiver
                                      ↓ 验证/选源
                    ComplicationPresentation(snapshot, metric, now)
                            ↓                       ↓
                 四种WidgetFamily / 总览         Watch指标详情
                            ↓ widgetURL              ↑
                      白名单URL → Watch导航目的地

已确认图标母版 → Asset Catalog → iOS / Watch启动图标
双端说明页 → 明确合成的独立预览（不写同步缓存）
```

## Affected files / planned

- Packages/WristlabCore/Sources/WristlabCore/ComplicationPresentation.swift：新增公共显示/路由/时间线接口。
- Packages/WristlabCore/Tests/WristlabCoreTests/ComplicationPresentationTests.swift：新行为测试。
- Apps/Widgets/WristlabWidget.swift：组件Bundle及四种布局。
- Apps/watchOS/WristlabWatchApp.swift：路由、指标详情与说明入口。
- Apps/iOS/SettingsView.swift、Apps/Shared/WatchFaceGuideView.swift：说明与预览。
- Apps/iOS/Assets.xcassets、Apps/watchOS/Assets.xcassets、project.yml：图标与URL声明。
- specs/001、003及README双语、docs/validation：同步验收含义和实际证据。

以上是已确认的实施范围；完成证据在 Build 报告逐项记录。

## Risks / Trade-offs

| 风险 | 缓解 / 验收边界 |
| --- | --- |
| 不同表盘不支持所有family | 提供多family，编辑器实际可选槽位及着色在模拟器观察，真机待补 |
| 一项过期导致总览全空或误显旧值 | 逐指标显示模型；快照过期才全局隐藏；严格边界测试 |
| 手机/手表演示泄漏进真实组件 | 真实Provider拒绝demo，预览独立，不改真实缓存策略 |
| 点击冷启动时导航丢失 | URL目的地作为Watch状态，冷/热各执行一次；解析器白名单测试 |
| 图标尺寸/遮罩与旧版actool差异 | 双目标实际编译，保留母版；必要尺寸适配列design-adjustments |
| STDD辅助命令部分不兼容 | extract-proposal解析器未正确提取canonical生成的capabilities，直接交叉核对YAML；experience命令缺requests，但本地经验目录为空，直接检查为空，不为此修改工具依赖；canon generate --all只扫描项目级目录，已直接调用原样固定上游的_generate_spec渲染change级规格 |
| STDD结构验证不检查完整业务或人工确认 | 独立核对Scenario/TC，保留人工Gate与设备证据 |

## Primary references (checked 2026-10-21)

- [WidgetKit组件](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications)
- [组件深链](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity)
- [应用图标目录](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [表盘分享要求有效资源](https://developer.apple.com/documentation/clockkit/sharing-an-apple-watch-face)

## Gate 2 execution mode recommendation

建议连续执行Build：新增/调整上述项目文件、运行Swift测试、尺寸导出、Xcode构建、模拟器安装与截图可自主完成；小偏差写design-adjustments，重大范围/隐私/健康算法变化暂停。无需扩大任何系统权限或配置Claude hook；账号登录和付费动作仍由用户执行。Gate 3保留人工确认，确认前不交付合并。普通模式亦可选择。
