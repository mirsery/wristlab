# 003 数据、报告与同步生命周期

## Watch独立数据分区（Gate 2已确认，WI-L/WI-S）

Watch本地只读既有五类、独立仓库/profile/producer/anchor/revision，数据窗口和规范沿用本文件；不假定Watch拥有手机全部历史。手机snapshot-v1通道保留且与local分区隔离。所选模式和相应最小快照用一个原子展示包供App/Widget读取，保存成功后才切换；演示不落真实存储。旧phone缓存仅首次缺新包时迁移，损坏包不触发回退。手机clearData只清phone分区，本地停止清除只清local并停止读取，双端确认文案明确范围；晚回调按generation/epoch拒绝。首版不新增后台机制或配置同步，iCloud保持关。权威设计与10场景见`.stdd/changes/2026-10-23-watch-independent/`，Gate 2确认后方可实施。

## 本地手动计划数据扩展（Gate 2已确认）

RepositoryState新增可选PlanningState；旧缓存缺字段按空状态读取，新状态包含运动计划版本、执行快照、手动体重和目标历史。与健康记录共用串行revision和原子文件提交，保存成功后才发布；失败不覆盖旧状态。HealthKit刷新与配置重建保留手动数据。“清除派生缓存并重算”保留这些数据；“停止读取并清除应用数据”全部删除，并以revision/界面generation防止晚到事务或错误恢复复活。

计划和体重仅本机，不进入Watch/Widget快照、日志或云服务。合成演示使用独立PlanningState，提交时核对演示来源，不落真实存储。首版手动体重不新增HealthKit类型或写入权限。

规格状态：已定义v1；运行状态：领域事务/快照已有单测；HealthKit和Watch适配器待本轮CI及真机验证。同步schema `snapshot-v1`。

## 读取与授权

PHC-001至007（手机连接修复，Gate 2已确认）：连接在首个await前显示系统请求/读取阶段并阻止重复授权，所有连接入口须就近展示反馈；设置弹层在连接按钮同组显示状态/忙碌，忙碌期间禁用连接和刷新，不依赖被遮住的首页或设置最底部。模型持有单个读取任务，不随页面或下拉刷新取消。并发普通请求加入当前工作，观察事件最多合并一次后续刷新，连接强制读取不得丢失；显式停止/清除仍取消工作并以generation/revision拒绝晚结果，不能重启已停止读取。缓存打开失败明确提示、原路径重试，不删除或覆盖失败文件；失败释放忙碌状态、保留报告/anchor/手动计划，空读取不推断拒绝授权。权限类型、评分、schema、默认无云不变；2403及后续修复版同包安装与健康真实读取分别验收，手表开发连接阻塞另记。具体规格与合成/真机边界见`.stdd/archive/2026-10-24-phone-health-connection/`。

Watch日常活动WDA独立于下述评分读取：用户主动连接后仅只读stepCount和activitySummary，统计最近7个系统日、当天截至读取时刻，不跨来源自行相加。圆环按Apple返回Move模式/目标/暂停展示，未知不补默认目标；前台/手动刷新、分项失败/时间明确，非实时、无新增后台。心情不写HealthKit，仅Watch私有受保护文件的当天一条。可选care投影与原Watch展示包同次原子写入，40KB总上限不变，不含心情、不改snapshot-v1手机协议；手机clear只清phone分区，停止活动只清活动，全手表本地清除须明确包含评分/活动/心情并先持久停止标记防复活。

ACAL-001/002/003：活动摘要谓词日期必须显式携带Gregorian calendar及同一系统时区的era/year/month/day，保持原系统日，含近午夜及23/25小时DST。原连接/缓存触发前台刷新也不得因缺calendar抛出Objective-C异常；SDK谓词构造须使用生产参数测试，而非仅验证演示DTO。不以卸载/清缓存/关闭功能规避，2402真机验证单独记录。

用户主动操作后只读HR、RHR、HRV SDNN、sleepAnalysis、workout；不请求写权限。iOS 18及以上，用户在心情卡片另行主动连接后只读State of Mind：单独授权、单独查询，不进入评分读取类型、锚点、规范记录仓库或Watch快照，只在内存中用于并列显示（见001“心情记录与压力对照”）；空结果不推断denied。活动能量后续只显示原始值，不参与v1公式。先判断HealthKit支持情况；请求完成再查询，空结果用中性文案，不推断denied。

初次读取D之前60个完整分析日至asOf，sleep额外前取一天作边界缓冲。查询包括相交interval；保留原始时间；end>asOf的未结束原始sample不用于数值，未来完整sample隔离。合成测试与实际记录分开存储。

## 规范样本与来源

规范记录包含sampleID、类型、UTC start/end、标准值/单位、source bundle、device family及本地设备ID、手工标记、导入revision、同步版本（存在时）。HR/HRV/RHR允许start=end；sleep/workout要求start<end。技术有效范围为有限数HR/RHR `(0,300] bpm`、HRV `(0,5000] ms`；仅为异常输入护栏，不是正常医学范围。

同ID幂等upsert，删除按ID；更新有同步版本则高版本胜，无版本冲突重新查询。不同ID但同类型/source/device/start/end/标准值视为重复，取ID字典序最小代表。跨设备近似数值不是同一原始样本。

数量来源按类型分开：用户选定顺序 > Apple Watch > 支持该类型的第三方 > iPhone；手工数量不参与v1估算，可在本地原始记录中另行展示。自动候选来源须在评估日D之前60个分析日的本地午夜至asOf（按样本end，两端包含）有至少一条有效数量样本，再按既有优先级及同级sourceID升序选单组；保留窗口外数据不能单独让来源成为自动候选。显式preferredSources中仍有保留有效记录的组继续优先，不静默替用户改源；组为bundle+device family。选定后保留该组全部有效历史供回放，数量类型分别选组。一次revision内固定组，不逐缺口填入低优先级来源；用户偏好或自动候选资格变化导致sourceSignature改变时，按新组全量重建并推进同步epoch。HR/HRV/RHR可分别选择，组成sourceSignature。

睡眠按[004](004-sleep.md)每报告窗口选源。准备度night和sleep压力的sourceSignature必须包含睡眠来源；dayFallback/awake不混入其他模式。设备同family更换仍可同组，原始去重仍保留deviceID。来源签名改变不能接旧基线/电量检查点。

## 时间规则

- 区间统一 `[start,end)`；HR/HRV按end归属桶。RHR按start所在分析日归属，再按end选最新。
- analysisTimeZone首次默认设备时区并持久化；旅行不自动改。用户改时区使日摘要/睡眠/基线/趋势/电量重算，升配置版本。
- 分析日用Calendar本地午夜到下一午夜，可能23/24/25小时；时长用UTC秒差。桶按Unix epoch对齐5分钟，不等于本地日边界。
- 全部函数显式接收asOf，只用已结束样本。历史修订用明确数据集revision回放；迟到数据可改变历史，但不伪装为原先已知。
- 压力/电量15分钟有效期、准备度归属日、传输快照60分钟是不同层次；界面采用更严格状态。

## 报告契约

正式DailyReport/MetricEstimate应替代旧演示DashboardSnapshot的有限字段；旧容器不是已实现的同步schema。

| 字段组 | 约定 |
| --- | --- |
| identity | schemaVersion、modelVersion、configurationVersion、inputRevision、analysisDay、analysisTimeZone |
| evaluation | asOf=评估截止时刻；computedAt=执行时刻；重复执行不改变值和原样本年龄 |
| provenance | demo/healthKit、sourceSignature、latestSampleAt、输入数量；原始sampleID仅本地解释 |
| metric | value?、rawValue本地、availability、dataQuality?、reasonCodes、mode、窗口、validUntil、baselineDays、coverage?、分项贡献 |
| 报告附带（iPhone本地） | stressTimeline为D-6前15分钟至asOf的5分钟压力桶；history为35个分析日；energy驱动区间与personalRanges为可选展示字段；均不进入Watch快照 |
| sleep/activity | 模块独立可用/缺失，不因一项不足把整份报告判失败 |
| revision | 内容原子提交成功后递增；仅computedAt变化不无端发同步 |

reason codes固定集合：noReadableSamples、missingCurrentHRV、missingCurrentRHR、missingPrimarySleep、baselineNotReady、hrOnly、missingHR、lowCoverage、observationGap、recalibrationRequired、missingMaximumHR、missingHistory、sourceConflict、aboveConfiguredMaximum、awaitingSync、stale、unsupportedSchema。首要提示依次为不支持/必要输入缺失/校准/低覆盖/部分质量/过期；允许多原因。

## 增量、事务、失效传播

1. 手动刷新、前台恢复、HealthKit观察更新触发读取；观察只表示可能变化，后台执行机会由系统决定。
2. 每类型持久化anchored增量及deleted IDs；初次、anchor失效、配置切换走受限全量重建。
3. 串行协调器为一个批次分配inputRevision，顺序为睡眠→基线→准备度/压力/活动→电量→报告；取消旧任务不能覆盖新revision。
4. 规范记录、摘要、检查点、报告、anchor原子提交；失败整体回滚，不提前推进anchor。
5. 插入/更新/删除使受影响日、随后60日的基线结果、最早受影响步骤之后的电量链失效；源/模型变更可重建保留窗口，不能只改今日。
6. 初次60日窗口不保证立即拥有90日报告；后续积累形成历史。源/时区/模型切换若需重算最近90日报告，允许按需重新读取至D之前150日（90+60）及睡眠边界缓冲；权限/历史不足处明确缺失，不混用旧profile摘要。首版实现为保留最多150个分析日的规范记录，按需全量重放最近报告，暂不依赖有损摘要或增量电量检查点。界面保留7/30日趋势与近7日回顾（history为35个分析日，见001“长期趋势与近7日回顾”），后续90日报告缓存再独立优化。重算90日需相应历史均可用；不足处标缺失。超过窗口的删除/修订若无法验证检查点，废弃它并重新seed，不承诺恢复任意历史。

## Watch协议

iPhone是真实评分权威，Watch不独立建立基线。以已激活WCSession的updateApplicationContext发送最新完整展示快照；允许被更新值替换，因为它不是必须完整送达的事件流。可达时可请求一次刷新，不可达保留缓存并显示awaitingSync。

envelope≤32KiB，包含schema、source、producerID、epoch、sequence、asOf/computedAt、模型/配置版本、日期时区、各指标值/质量/时效/必要解释、sleep/activity概要、clearData。无原始HR序列、sampleID或真实设备标识。producerID是应用本地随机ID。

同producer按(epoch,sequence)词典序只接受较新；重复幂等。epoch为持久化递增整数，模型/源/时区全量切换和清数据时递增；epoch内sequence递增。完成schema和值校验后原子换缓存，未知schema/非法payload保留旧值并提示。

首次producer只从已配对已激活会话建立信任；变化时Watch要求用户确认连接新手机，不能只凭更晚时间覆盖。卸载重装走新producer确认；时钟回退不能使旧sequence胜出。

清数据先持久化递增epoch及clearData空快照tombstone，删除展示缓存后发送。Watch收到后原子清App和组件缓存，拒绝旧epoch，避免延迟旧报告复活。保留必要同步控制元数据；离线无法立即清远端，显示等待手表同步。

快照computedAt距当前>60分钟或处于未来为过期；单指标更严格有效期仍生效。WidgetKit从Watch本地App Group读同一快照，按系统预算请求更新，不承诺固定刷新间隔。iPhone小组件从iPhone App Group读取手机每次发布的同一份真实快照（演示不写入；清除写入标记，写失败时删除文件回到等待），显示规则与表盘组件相同。

## 本地通知

晨报是本机生成的本地通知，不经过任何服务器。显示数值时内容会出现在锁屏和通知中心，并可能按系统设置转发到配对Watch；默认隐藏数值。清除数据会撤回已送达的晨报。

## 清除和撤销

清派生缓存：保留规范记录和设置，发送清除快照，再全量重算。停止读取并清应用数据：停观察、取消任务，删规范记录/派生结果/anchor，仅保留同步控制元数据；同时清空内存中的心情记录并忘记心情连接请求、撤回已送达的晨报通知，重新连接需在心情卡片再次主动发起。不删除Apple健康原始记录。

系统撤销读权限不能可靠检测为一个denied事件；后续为空显示中性缺失和最后记录时间。提供显式清除操作，不因推测撤销就声称本地/离线Watch已全部清空。

## 验收标准

可选CloudKit只用于P-024/P-025界面偏好，独立DTO与缓存，不复用RepositoryState序列化、不更改HealthKit只读和健康数据本地边界。账户切换仅隔离云偏好，不自动删除设备上的健康记录；应用不是按Apple ID登录的多用户健康库。签名容器/环境核验与服务器真实可用性分别验证，首次未知配置SDK错误中性显示，不采用私有API检查entitlement。

自动完成度扩展仅复用只读HKWorkout权限，HealthRecord追加可选duration及活跃区间；旧缓存缺字段仍可解码，但不猜算运动分钟。用户可主动全量重读窗口内旧运动记录。PlanningState可选自动计划、采纳版本及模式历史仍通过现有revision/原子事务保存；演示隔离，清除遵循既有设置保留选项，计划/体重不进入Watch或Widget快照。

- H-001：支持性、授权请求错误、空/部分类型记录分别验收，无真实健康日志。
- H-002：单位、时间保真，未来/非法/未知单位不进估算。
- H-003：去重、选源、删除、时间边界/时区有确定结果。
- H-004：同数据全量与增量一致；旧任务不覆盖新；崩溃不提前推进anchor。
- H-005：断连、乱序、重复、旧epoch、新producer、未知schema与离线清除均保持协议约束。
- H-006：快照60分钟或未来过期，指标时效独立；旧容器只覆盖基础判断。
- H-007：手机/Watch/组件同revision同值；后台调度需真机观察，不能用固定分钟验收。
- H-008：晚到、删除、配置变化传播失效；旧模型检查点不得接续。

## 组件展示扩展（Gate 2已确认，实施中）

保持既有缓存/schema及WristlabEnergy kind。真实组件拒绝demo快照；展示空、清除、校准、失败和过期等状态，单指标独立时效，快照全局过期时全部隐藏数值。真实0仍显示0。为已有严格大于时效边界预排后一秒的entry，不承诺系统准点切换；clearData实际收到后才可清除远端。URL仅携带白名单目的地，不带健康值。

### Watch 主动刷新回执（H-007，Gate 2 已确认，真机验收待完成）

用户随后确认当前默认不启用iCloud：默认构建不申请CloudKit签名权限且运行时云入口为未配置；实现保留，未来通过显式CloudKit构建配置启用并另行验签。此设置不关闭WatchConnectivity，不清除本地数据或修改健康读取范围。

发送刷新请求不代表手机收到，也不代表生成或接收新快照。请求状态 SHALL 区分不可达/激活失败、等待回执、手机处理结果及实际快照接收保存。手机已有合法快照时优先交付已有快照并尝试刷新；不得将旧缓存描述为本次新数据。无快照、未连接健康或刷新失败 SHALL 提供无健康值原因。等待回执15秒后结束等待，不循环重试；重复请求合并，迟到响应按请求标识隔离。保留旧refresh和applicationContext兼容，回复中快照经过相同版本、producer、清除与落盘规则。只有实际接收且保存成功可提示收到数据。旧手机不回复时超时不等于手机离线。真机更新方案另行确认，不因CloudKit签名限制静默覆盖手机。

对应SC-001至SC-005及TC-WRH-001至TC-WRH-005，详见`.stdd/changes/2026-10-23-watch-refresh-handshake/`。

Watch 收到回复或发送失败的回调来自 WatchConnectivity 后台队列，SHALL 以非隔离 `@Sendable` 处理后再回到主线程更新状态；2405 因 MainActor 闭包在该队列触发隔离检查而退出，由 `.stdd/archive/2026-10-24-watch-refresh-exit/`（WRX-001–003）修复，2406 真机 Gate 3 已确认；协议、状态、15 秒超时与文案不变。

### Watch 缓存落盘验收细则

H-005/H-007 的共享缓存仍位于 App Group 的 watch-receiver.json。适配器 SHALL 仅对应用拥有的缓存文件设置备份排除，不修改系统管理的共享容器根目录元数据；保存采用原子写入和首次解锁后文件保护。文件保存失败 SHALL 保留上次内存快照并明确提示保存失败，不能提示为协议无效。成功接收后的重新启动 SHALL 恢复相同缓存供应用与组件展示。
