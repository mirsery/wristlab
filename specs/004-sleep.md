# 004 睡眠业务

规格状态：可实现；运行状态：待实现。模型 `wristlab-sleep-v1`；阈值为产品约定，不是临床定义。

## 窗口和选源

分析日D睡眠窗口为D-1日12:00至D日12:00，按分析时区Calendar建边界，UTC秒差算时长。读取边界缓冲，计算裁剪至窗口，不重复计入相邻报告。

每窗口一个来源组，用户优先顺序 > Apple Watch > 提供asleep的第三方 > iPhone。高优先级在窗口无任何有效asleep时才回退；不按缺失阶段拼其他源。用户配置是优先级顺序，非强制锁定。只有inBed可独立展示卧床，但不是睡眠。

同源去重后按所有边界拆原子区间，inBed独立覆盖层不与asleep相加。具体阶段胜asleepUnspecified；若同一区间具体阶段冲突或awake/asleep冲突，标unknown+sourceConflict，不猜阶段。各类resolved区间只算一次。

## 段、主睡眠、小睡

相邻resolved asleep片段间隔≤90分钟合为episode；间隔只有明确awake部分计awake，其余unknown，均不计睡眠。>90分钟拆段。

episode实际asleep≥20分钟才进入汇总；较短记录保留原时间线但不进主睡眠、小睡或债务。原始样本已结束且末次asleep距asOf≥90分钟时为completed；否则ongoing仅供预览，不作准备度输入。

completed中实际asleep≥180分钟的最长episode为主睡眠；同长选结束较晚，再ID字典序最小。其余达20分钟为小睡，白天也可能主睡眠。没有180分钟段时仍展示已记录睡眠，准备度没有night输入。

D日14:00前provisional，此后settled仍可修订。跨中午episode会被窗口裁剪成两段并标clipped，这是v1限制，不能重复计两天。

## 汇总

| 指标 | 规则 | 缺失 |
| --- | --- | --- |
| actualSleep | core+deep+REM+unspecified并集 | 无asleep为空，不用inBed代替 |
| 各阶段时长 | resolved具体阶段时长 | 无任何具体阶段时为空，不把未知设core |
| 阶段比例 | 各类/actualSleep，含unspecified和为100% | unspecified存在标partial |
| 深睡+REM | 已识别两类之和 | 无具体阶段为空 |
| 卧床 | inBed并集 | 无inBed为空 |
| 效率 | 与主episode相交的完整inBed并集为分母，asleep与该并集交集为分子 | inBed裁剪报告窗口但不裁成episode；分类覆盖≥80%才给，有unknown则partial |
| 入睡潜伏 | 覆盖首次asleep起点的同段inBed起点至首次asleep起点 | 该前缀需全部明确awake，无边界/分类则为空 |
| 清醒 | resolved awake时长，相邻awake合并计次数 | 称已记录清醒，未知不当awake，边界可能缺失 |
| 睡眠HR/HRV | 已选数量来源中落在asleep内样本中位数、列数量 | 分别缺失，不借清醒记录 |

若完全没有具体阶段，具体阶段时长/占比和深睡+REM为空，unspecified可显示；不能把未测得阶段显示成0。已有具体阶段时，未出现的具体阶段为0，unspecified仍单列，四项占比和为100%。

总睡眠/债务含全部completed合格episode，准备度仅主睡眠，ongoing不进总量。v1无综合睡眠分，不猜测原版公式。

## 债务与规律性

睡眠目标由001设置，改目标升配置并重算。

稳定且有合格asleep的报告日为有效日。无样本是unknown。用户可明确标记本窗口未睡（本地标注，不写HealthKit），形成actualSleep=0的有效日；后续出现合格asleep则实际记录优先，不再应用0标注。

7日债务截止最近已settled报告日，要求连续7个有效日：`max(0,7×targetMinutes-ΣactualSleepMinutes)`。固定窗口内多睡可抵少睡，不无限累计。缺一日则债务为空，可列已记录总量/有效数但不外推。

规律性要求同样7日全部有主睡眠。将起点转分析时区钟表分钟，以12:00展开：`u=(clockMinutes-720+1440)%1440`。reference=median(u)，deviation=median(abs(u-reference))，单位分钟，越小越规律。它不是经验证睡眠规律指数；跨午夜可比，穿越12:00展开边界的轮班模式是明确限制，不生成综合健康标签。

## 验收标准

- SL-001：inBed/阶段不重算，源不混拼，冲突为unknown。
- SL-002：20/90/180分钟边界、同长排序和主/小睡确定。
- SL-003：只有时长照常展示，阶段/效率/潜伏不足为空，不编awake/asleep。
- SL-004：跨中午/午夜/DST、ongoing和迟到修订符合窗口。
- SL-005：债务少一天为空，明确未睡与未观测分开，午睡计总量。
- SL-006：23:50/00:10附近不产生一天偏差，轮班限制说明。
- SL-007：源/时区/目标/删除使依赖重算，保留数据时间与阶段。
