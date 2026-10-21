# 003 数据、报告与同步生命周期

规格状态：已定义v1；运行状态：领域事务/快照已有单测；HealthKit和Watch适配器待本轮CI及真机验证。同步schema `snapshot-v1`。

## 读取与授权

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

## 清除和撤销

清派生缓存：保留规范记录和设置，发送清除快照，再全量重算。停止读取并清应用数据：停观察、取消任务，删规范记录/派生结果/anchor，仅保留同步控制元数据；同时清空内存中的心情记录并忘记心情连接请求，重新连接需在心情卡片再次主动发起。不删除Apple健康原始记录。

系统撤销读权限不能可靠检测为一个denied事件；后续为空显示中性缺失和最后记录时间。提供显式清除操作，不因推测撤销就声称本地/离线Watch已全部清空。

## 验收标准

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

### Watch 缓存落盘验收细则

H-005/H-007 的共享缓存仍位于 App Group 的 watch-receiver.json。适配器 SHALL 仅对应用拥有的缓存文件设置备份排除，不修改系统管理的共享容器根目录元数据；保存采用原子写入和首次解锁后文件保护。文件保存失败 SHALL 保留上次内存快照并明确提示保存失败，不能提示为协议无效。成功接收后的重新启动 SHALL 恢复相同缓存供应用与组件展示。
