# Watch 独立健康报告设计（Gate 2 草案）

## Context

当前Watch只接收手机DisplaySnapshot；用户已确认同步修复后可看到快照。独立功能不得破坏现有手机模式。Core已有HealthRepository、HealthEngine、SnapshotReceiver和WatchSnapshotDelivery；HealthKit适配器当前在iOS，含iOS专属心情API，不能直接整体加入Watch target。

本阶段仅设计，不实现或安装。iCloud默认关闭不变。Apple支持Watch侧HealthKit，但可读历史和实际记录不假定等同iPhone；不承诺立即出分。

## Decisions

### 1. 两个明确模式，不自动择优拼分

升级保留“手机同步”和当前快照。新安装首次显示“连接手表健康，独立使用”和“使用手机同步”；用户主动选择本地、完成授权请求后即固定本地模式，即使没有数据也显示真实缺失原因，不回退手机。菜单可切换模式并显示两份报告的时间及可用状态；切换有独立任务generation，旧异步工作不改变新模式。手机恢复连接只更新手机缓存，不覆盖当前本地显示。

不采用“谁新用谁”或逐指标拼接：两份报告输入、配置、基线可能不同，隐式切换会产生难以解释的跳分。来源显示“手表本地计算 / 手机同步”，HealthKit数据来源和报告生产设备是不同概念。

### 2. 手表只读健康并复用全部核心计算

读取白名单保持HR、RHR、HRV SDNN、sleepAnalysis、workout；无写权限、无心情、无传感器连续采样。共享规范转换/查询适配，iOS心情代码拆在iOS专属扩展。Watch本地首次查询与003同一60完整分析日加睡眠边界缓冲规则，平台返回不足就如实保留；查询分类型/有界批次、支持取消与串行合并，避免无界结果占内存。anchors、删除和失败提交遵守原事务规则。

watch-local仓库拥有独立producer、revision、epoch、records、anchors、profile；不合并手机原始记录、分值或基线。同输入同配置同asOf用原HealthEngine应得同结果，公式及模型版本不变。原14有效日门槛不降；历史不足显示X/14，当前输入缺失按原原因提示，不声称权限被拒绝。Watch可逐次积累本机可读记录，按现有上限保留，不能承诺何时凑够基线。

### 3. 配置本地拥有，不偷偷继承手机

首版不新增配置同步协议。新本地配置采用现有HealthProfile默认值：首次设备时区固定为分析时区、睡眠目标8小时、maxHR未知、maintain、自动来源；连接前展示并可修改分析时区/睡眠目标/maxHR/训练模式。maxHR不猜值，依赖其的计算保持缺失。配置修改走仓库configure原子重算和epoch推进；时区变化需确认，不跟随系统移动而静默重算。偏好来源与确认无睡眠等高级配置暂不新增Watch编辑入口，按本地默认/已有状态执行。界面明确“手表设置独立于手机”，以后同步需另设计。

### 4. App与表盘只消费一个已选报告包

新增WatchDisplayEnvelope：schema、selectedMode、报告生产设备标记、可选DisplaySnapshot、选择generation与保存时间；不更改原snapshot-v1语义。手机receiver仍单独保存原watch-receiver.json；本地仓库与新展示文件分开。Core纯选择模型产出展示包；App/Widget共用选择规则。切换或刷新时，先原子保存包含所选模式和相应快照的单一展示包，再更新可见状态并reloadTimelines，失败保留旧模式与报告。Widget不从两个文件逐指标拼装。

展示包另含localReadState（notConnected/enabled/stopped）和本地清除控制版本；该状态不是授权许可推断。停止清除流程先取消并推进内存generation，再原子持久化stopped和本地清除投影，最后清仓库；清除标记保存失败则不继续删仓库，明确“清除未完成”，不声称已清。标记已保存而仓库清除失败时，重启仍按stopped隐藏旧本地数据且不启动读取，继续清理并提示失败；不能因仓库残留readingEnabled=true恢复观察。后续主动重新连接先完成待清理事务，再建立新的读取代次。此隐私操作区别于普通投影失败的保留旧显示策略。

本地仓库提交后展示包提交失败：仓库保留已提交结果，UI明确“展示缓存更新失败”，仍显示旧已提交包，下次重试投影；不能称本次表盘已更新。外部组件链接不改变模式。首次缺新展示包才迁移旧手机receiver；展示包损坏不能当成首次安装回退旧缓存，显示存储错误并保留文件。演示继续独立，不进入展示包或真实仓库。系统控制组件预算，App写入与组件刷新调度不保证同时可见；两者消费同一已提交包。

### 5. 清除按来源分开，避免破坏独立数据

Watch“停止手表读取并清除本地数据”只清本地健康仓库与本地投影，停止本地任务/观察，推进generation与epoch，保留必要同步控制；继续处于本地未连接状态，不跳到手机缓存。重新读取必须主动授权流程，晚到任务不得复活数据。手机收到的普通clearData仅清手机快照分区，不清手表独立仓库。手机清除确认文案需明确“会清除手表中的手机同步副本，不会删除手表独立记录”；Watch本地清除不删除Apple健康原始数据或手机数据。

这里选择分区清除而非全设备远程删除，避免旧手机clearData缺意图字段而误删本地。若用户需要一键双端全清，另设计带确认回执的控制协议，不用普通快照推断。选中手机模式收到清除时显示清除态；选中本地模式时只提示手机副本已清，保留当前本地报告。

### 6. 前台独立优先，后台分阶段

本次范围是首次授权、打开App及手动本地刷新、结果投影和已有组件时间线；不增加专用后台刷新机制或常驻模式。前台退出/锁屏失败保留缓存并有时效。后续系统后台机会单独评估、真机验证后再接，不用运动/音频session续命。工程声明允许不依赖手机运行，保持companion身份兼容已有安装；具体Info键、watchOS HealthKit权限与API按本机SDK及签名核验，不做独立上架或Family Setup承诺。

## Architecture

WatchLocalHealthReader → 独立HealthRepository → 同一HealthEngine → local DisplaySnapshot

手机 → WatchBridge → SnapshotReceiver / WatchSnapshotDelivery → phone DisplaySnapshot

两个snapshot分区 + 用户mode → Core选择模型 → 原子WatchDisplayEnvelope → Watch UI / App Group Widget

新协调器在MainActor管理请求/模式/清除generation，仓库actor串行提交。App不直接查询HealthKit，组件只读展示包。签名仅新增Watch所需只读HealthKit能力，不启用iCloud；敏感健康仓库存Watch应用私有Application Support，App Group仅最小展示快照。文件保护/备份排除沿用已验证策略。

## Risks / Trade-offs

| 风险 | 决策/验证 |
|---|---|
| Watch历史不足14有效日 | X/14及原因；不承诺手机同分，也不搬运原始记录 |
| 两端配置不同 | 独立设置与明确来源；同输入同配置合成对照 |
| 模式/刷新/清除竞争 | generation、独立revision、不跨producer比较；可控传输/时钟测试 |
| 双文件跨事务不原子 | 展示包单文件作为显示提交点；仓库成功/投影失败可重试 |
| 新旧组件缓存迁移 | 仅缺文件迁移，不因损坏回退；旧系统schema不改写 |
| 用户以为手机清除是全设备删除 | 修改确认范围文案；清除两分区独立验收 |
| 耗电与内存 | 有界批次、串行合并、取消、前台实测；不宣称已有性能数据 |

## 实施顺序与验收门

1. 模式/展示包/迁移/清除纯模型与失败测试。
2. 共享适配器拆分、Watch授权/仓库/前台读取，保留iOS心情路径。
3. 本地设置、来源/原因UI、组件选择、签名与升级。
4. 双端模拟器构建和组件检查，三路只读评审，再真机断开手机授权/刷新、重连、重启、清除验收。

Gate 2待用户确认；不把设计通过或模拟器构建当成可读历史/后台行为/真机安装成功。

## 依据

Apple文档：https://developer.apple.com/documentation/xcode/configuring-healthkit-access 、https://developer.apple.com/documentation/technotes/tn3157-updating-your-watchos-project-for-swiftui-and-widgetkit 。本机WatchOS SDK HKHealthStore.h用于后续接口可用性核对。历史上限未从一手材料确认，不填固定天数承诺。经验CLI缺requests，手动参考EXP-20261023-009：发送不是接收、冷启动先恢复缓存、落盘后才提示成功。
