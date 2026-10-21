# iPhone主屏与锁屏小组件 - 技术设计（Gate 1/2已确认，实施中）

## Context

iPhone每次刷新由HealthRepository产出DisplaySnapshot（最小、已去掉贡献项、带epoch/sequence/生成时间/来源），并经WatchBridge发给Watch。Watch组件读App Group中的SnapshotReceiver文件，显示逻辑在Core的ComplicationPresentation/ComplicationTimeline（缺失、过期、等待、已清除、真实0）。iPhone目前没有App Group与小组件扩展。WidgetKit注册时拒绝插值的配置名称（EXP-20261021-002），已有watchOS宿主运行检查。

## Decisions

### 1. iPhone独立App Group与快照文件
**方案**：iOS应用与新扩展共用`group.com.mirsery.wristlab.phone`；DashboardModel在每次发布真实快照（启动恢复、刷新、保存设置、清除）时，经Apps/Storage的SnapshotCacheFile原子写`phone-snapshot.json`（DisplaySnapshot.encoded()），随后`WidgetCenter.reloadAllTimelines()`。演示从不写入。
**为什么**：复用同一快照与原子写，不新增计算；与Watch组的group、文件、协议互不影响。
**备选**：共用watch的group——跨平台容器不共享且语义混淆；写SnapshotReceiver——iPhone是生产者，不需要接收端的epoch确认。

### 2. Core解码与汇总
**方案**：Core新增`PhoneWidgetCache.snapshot(from:)`（≤64KB、DisplaySnapshot解码与validate、仅healthKit来源；清除标记保留）与`PhoneWidgetSummary(snapshot:at:)`（准备度/电量/压力三个ComplicationPresentation与更新时间；等待状态在手机上改称“打开Wristlab刷新”），时间线沿用ComplicationTimeline.dates。缓存上限与DisplaySnapshot一致为32KB，App Group常量放在Core。
**为什么**：与Watch组件同一显示规则，避免两端映射不一致（EXP-20261021-001）。

### 3. 小组件扩展
**方案**：新target WristlabPhoneWidget（iOS app-extension），一个固定名称的配置“Wristlab 状态”，支持systemSmall（准备度数值与原因+电量/压力）、systemMedium（三项及原因）、accessoryCircular（准备度）、accessoryRectangular（三项）、accessoryInline；无数值显示原因（圆形也显示），部分估算标注，过期隐藏数值；背景固定深色并强制深色配色以保证原因文字可读；按快照时区显示时间；视图`privacySensitive`；点击打开应用。
**为什么**：一个配置覆盖常用位置，名称固定避免注册崩溃。

### 4. 注册运行检查与CI
**方案**：`scripts/test-widget-registration.py`增加`--platform ios`，在iOS模拟器宿主执行生产配置body并要求成功标记；build-apple.sh在watchOS之后运行iOS检查；CI apple作业超时由25分钟提高到40分钟。
**为什么**：注册期崩溃只能运行时发现；上一轮CI已用到约18分钟，新增构建与检查需要余量。

## Architecture

```text
HealthRepository → DisplaySnapshot ─┬→ WatchBridge（不变）
                                    └→ PhoneWidgetStore → App Group(phone)/phone-snapshot.json
WristlabPhoneWidget Provider → PhoneWidgetCache.snapshot → PhoneWidgetSummary + ComplicationTimeline.dates → 视图
```

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 注册期崩溃 | 固定名称；iOS注册运行检查 |
| 演示数据进入组件 | 只在真实快照路径写；Core拒绝demo来源 |
| 锁屏泄露健康数值 | privacySensitive，由系统设置决定是否遮盖 |
| 真机签名 | 新App Group需在安装时由Xcode自动注册，不提交团队配置 |
| CI超时 | 超时提高到40分钟 |
