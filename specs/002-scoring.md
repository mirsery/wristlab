# 002 准备度、压力与身体电量

规格状态：可实现；运行状态：领域计算已实现，覆盖金例与边界测试，见[验证记录](../docs/validation.md)。模型版本 `wristlab-physiology-v1`。下述公式与参数全是Wristlab实验约定，未验证效果，不声称还原原版精确算法。

## 公共规则

输入先执行[003](003-health-and-sync.md)；睡眠依赖[004](004-sleep.md)。`clamp(x,a,b)=min(max(x,a),b)`。内部Double不提前取整；显示时四舍五入，.5向上。缺失不能参与公式或当0。

每项结果包含value?、availability、dataQuality?、reasonCodes、mode、modelVersion、configurationVersion、inputRevision、analysisDay、windowStart/End、computedAt、latestSampleAt?、validUntil?、baselineDays、coverage?及分项解释。

| 参数 | v1值 |
| --- | --- |
| 基线窗口 | 评估日之前60个分析日，不含当天/未来 |
| 最少历史 | 每种模式14个有效日，14–59日显示实际天数 |
| 稳健中心 | median，偶数样本取中间两项算术平均 |
| 稳健尺度 | max(1.4826×MAD, floor)，MAD=偏离中位数绝对值的中位数 |
| 尺度floor | ln(HRV)=0.10，RHR=3bpm，压力HR=5bpm |
| 标准化贡献 | 每项截断到[-3,3]，不改写原始显示数据 |
| 压力桶 | UTC按Unix epoch对齐5分钟，[start,end) |
| HRV复用时长 | 到当前桶结束不超过3小时，同情境且非运动 |

先得到每日摘要，再以日为等权样本建基线。按night/dayFallback、awake/sleep、HRV算法和sourceSignature分开，禁止混合。所有参数变化升版本并重算。

## 训练准备度

### 输入、回退、基线

分析日D、asOf只读取end≤asOf的样本。

所有准备度HRV先排除与workout及其前后30分钟相交的样本；night与dayFallback遵循相同排除规则。

1. 主睡眠完成（结束至少90分钟）且其resolved asleep内至少2条HRV：取HRV中位数，作为night输入。
2. 当日RHR：start归属D，取end最新的有效记录；同end取start较晚、再取ID降序。无当天RHR则等待，不借昨天。它是日静息心率，不称为睡眠心率。
3. night条件不满足时，可选dayFallback：取D日非workout及非运动前后30分钟的全部HRV中位数，至少1条，加当日RHR。显示“日间估算”。
4. night当前输入够但night基线不足时保持校准，不为出分切换dayFallback。回退仅由夜间输入条件决定。
5. 各历史日按同样规则形成(lnHRV,RHR)成对摘要。每个模式各需14对；同一历史日可独立形成两种摘要，不能把二者混入同一分布。

```text
zH=clamp((ln(HRV_D)-median(lnHRV_history))/scaleH,-3,3)
zR=clamp((median(RHR_history)-RHR_D)/scaleR,-3,3)
readinessRaw=clamp(50+15×(0.7×zH+0.3×zR),0,100)
```

显示整数0–32“较低”、33–66“接近个人常态”、67–100“较高”，仅为产品分段。相同night输入全天同值；晚到、删除、RHR或基线更正可生成修订。dayFallback随新样本更新。D日14:00前provisional，之后可用报告settled；settled仍可修订。

准备度只属于D，D+1无值时当前为空，可另显示D历史。展示用的“个人基线区间”由同一夜间基线派生（中心±0.5尺度），定义见001“长期趋势与近7日回顾”，不参与计算。高分不自动等于可以高强度训练。

## 分时生理压力

### 基线与桶输入

awake基线日：排除睡眠及workout前后30分钟，至少12个不同桶有HR，最早最晚HR跨度≥4小时；取桶HR中位数的中位数为日HR，取同情境至少1条HRV的ln中位数为日HRV。

sleep基线日：主睡眠至少12个桶有HR且至少2条睡眠HRV；同样取日中位数。每情境至少14个成对有效日。

桶HR取按end落桶的HR中位数，无HR则桶为空，不沿用上一桶。HRV取end时刻落入同情境、非运动及非运动前后30分钟、end落在桶结束之前（严格小于右边界）、距桶结束≤3小时的最新样本；同end按ID降序。恰好右边界样本归下一桶。

桶中点决定sleep/awake；跨sleep/awake边界的桶标partial+sourceConflict，不声称整桶为同一状态；与workout有任意正时长交集则优先activity。activity用awake HR基线，忽略HRV，标“运动中”。sleep基线不足不借awake；awake不足则activity压力也为空。

```text
zHR=clamp((HR_bucket-baselineHR)/scaleHR,-3,3)
zHRV=clamp((baselineLogHRV-ln(HRV_recent))/scaleLogHRV,-3,3)
有HRV：stressRaw=clamp(50+15×(0.7×zHR+0.3×zHRV),0,100)
无HRV或activity：stressRaw=clamp(50+15×zHR,0,100)
```

有HRV且基线齐全为complete；无HRV/activity为partial+hrOnly。它表示输入质量，不是置信概率。按显示整数0–19低、20–59常态、60–79偏高、80–100高；夜间不猜测原版未知分界。当前值取最近有效已结束桶，桶end距asOf>15分钟为过期。

## 身体电量

### 合法起点

依赖asleep/workout区间和压力，不反向影响其他评分。首次种子是某已完成主睡眠对应night准备度首次可计算时的未取整值：E=readinessRaw；dayFallback不能建种子，不默认100。

重放保留历史时从最早合法种子开始。种子时间为主睡眠end+90分钟、所需当前样本end、历史输入就绪时间三者最大值，按整分钟向上取齐；该时刻按当时可用样本重算night准备度，不能拿当天更晚RHR倒灌到早晨。若那时尚未满足night模式，向后在输入变化时重试，最迟到D结束；之后需下一个主睡眠。原始导入时间不作为历史事件时间，但补录后的历史是“修订重建”，不能说是当时已经知道。

首次没有检查点可扫描最近60个分析日找最早合法seed；种子前为空。已有检查点只在模型、配置、来源、时区和输入摘要兼容时接续。

### 积分规则

按UTC整分钟切步，睡眠/运动边界额外切分，单步≤60秒；dt为小时，E为步前Double。互斥优先级如下：

| 情境 | rate（每小时） | 输入 |
| --- | --- | --- |
| workout最高优先 | -12×E/100 | 已记录运动，独立于MHR与压力 |
| asleep | +8×(1-E/100) | 明确asleep，不按阶段猜权重 |
| 清醒stressRaw<20 | +2×(1-E/100) | 对应有效压力桶 |
| 清醒20≤stressRaw<60 | -2×E/100 | 同上 |
| 清醒60≤stressRaw<80 | -5×E/100 | 同上 |
| 清醒stressRaw≥80 | -9×E/100 | 同上 |
| 未观测 | 不积分，内部保留最后E | 不当休息 |

`E_next=clamp(E+rate×dt,0,100)`，每步更新。只积分已结束压力桶；桶结束后可回放其自身区间，不外推其他桶。睡眠/运动按已结束原始样本积分到asOf。workout与sleep冲突标sourceConflict且只扣电。午睡与夜眠同机制，午夜不重置。电量读取全部resolved asleep时间线，包括尚属下一睡眠报告窗口的当日小睡，不等待该报告settled；但ongoing未结束的原始sample仍不参与。

### 缺口与质量

- 未观测段曲线断线；冻结内部E不代表维持体力。HR-only压力使对应电量段partial。
- 连续未观测≤30分钟允许接续并标observationGap；**超过**30分钟断链，此后当前电量为空，直到后续合法seed或补齐数据重放。
- seed到当前、最多最近24小时内：coverage=已观测时长/实际经过时长，种子时为1。低于80%当前值为空，内部可继续积分；恢复门槛后可再显示。
- 重新seed不是从100开始，原因recalibrationRequired明确展示。过期按最近实际积分时刻effectiveAt计算，>15分钟为过期；computedAt不能改变它。
- 删除、晚到、改配置从最早受影响步骤重放；无跨午夜取整。相同输入下清缓存与增量接续应一致。

## 验收标准

- A-001：0–100、解码校验、nil往返；现有容器仅覆盖基础边界。
- A-002：同规范数据/配置/asOf/revision结果相同，无隐式系统时间或提前取整。
- A-003：13日校准，14日可算；模式和来源隔离，解释包含实际历史数。
- A-004：常量历史用尺度floor；NaN/Infinity/未知单位/重复/乱序/未来值不污染。
- A-005：跨日连续，重复导入幂等；全量与增量/重启回放一致。
- A-006：公开模型版本，实验标签，无疾病/心理状态/受伤风险推断。
- A-007：HR-only部分质量，sleep/awake隔离，无HR不算，15分钟时效和右边界正确。
- A-008：seed、30分钟缺口、超30分钟断链、低覆盖与重新校准有明确结果。
- A-009：[006](006-acceptance.md)金例全部通过；公式变更同步版本/夹具/解释。

## 无电量起点的解释

无合法seed不等于缺少所有睡眠。若完成主睡眠对应夜间准备度因历史不足无法建立seed，电量 SHALL 保留calibrating、baselineNotReady及实际baselineDays；若已有主睡眠但夜间HRV或对应RHR缺失，分别给出必要输入缺失原因。只有没有已完成主睡眠才使用missingPrimarySleep。数值种子、14个有效日、覆盖和断链规则保持原定义。
