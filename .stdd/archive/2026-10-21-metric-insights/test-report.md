# 讲清楚已有估算：Build 测试报告

2026-10-22；分支feat/metric-insights，叠在PR #5（feat/watch-face-complications，c515ff6）之上。macOS、Swift 6、Xcode 27.1；iPhone 18 Pro模拟器（iOS 27.1，设备时区东八区）。全部使用合成数据。Gate 1/2用户已确认，Gate 3待确认。

## 执行结果

- `./scripts/check.sh`：通过，64 Core + 5 workspace测试，0失败。原50 Core全部回归通过，新增14个函数（TC-CONTRIB-005参数化14例）。规格52个既有验收ID、31场景、12份数值金例与3个活跃change的STDD检查通过。
- `./scripts/build-apple.sh`：iPhone、Watch与内嵌Widget模拟器构建通过，四个Widget配置注册运行检查通过。
- `git diff --check`：通过。覆盖率与e2e未启用，SKIPPED，不报百分比。
- `./scripts/stdd validate`：通过；两条“AND数量超过5”为spec.md文件级计数的警告。
- 日志（gitignored work/）：insights-s1/s2/s3-red.log为缺接口编译失败的RED证据；insights-s*-green.log、insights-final-check.log、insights-final-apple.log为GREEN与最终全量结果；insights-baseline-c515ff6.log为改动前代码跑出的数值基准。

## TC 实际对照

| TC | 结果 | 证据 |
| --- | --- | --- |
| CONTRIB-001～005 | 通过 | 5个函数；方向、阈值±0.5边界、差值按显示整数、U+2212负号、缺键/NaN/∞、过期与校准、内部键与z不出现、分段边界 |
| CONTRIB-006 | 静态+模拟器通过 | 首页无“给自己一点休息”等文案；截图首页“准备度较高”、压力卡“常态 · 基于个人历史”，详情页贡献行替代原始键 |
| TIMELINE-001 | 通过 | 准备度/压力/电量原值、841点的顺序加权校验和与c515ff6一致（含12:30午后小睡变体）；区间含下一睡眠窗口的小睡 |
| TIMELINE-002～005 | 通过 | 裁剪/排序/零长度、纽约2026-11-01的25小时日、旧JSON解码、压力断线与运动标记、电量nil断线、覆盖不足与过期隐藏电量曲线 |
| SLEEPUI-001～003 | 通过 | 真实SleepCalculator含清醒与冲突unknown段；无阶段为nil、阶段份额按阶段和；无记录时清醒为nil |
| SLEEPUI-004 | 模拟器通过 | 睡眠详情截图：合成标签、23:00–07:00、泳道与分析时区刻度、阶段份额、指标 |
| TREND-001 | 通过 | 7个固定日、缺失nil、均值与负荷均值、重复日、纽约夏令时周、asOf非零点 |
| TREND-002 | 模拟器+静态通过 | 三种切换截图；负荷不显示均值；VoiceOver标签含日期与值（静态审阅，未开VoiceOver实测） |

17/17 TC有对应验证；14个为自动测试，3个为模拟器截图与静态检查。

## 切片

| 切片 | TC | 新增测试 | 验证 |
| --- | --- | --- | --- |
| S1 贡献与分段 | CONTRIB-001～006 | 5 | RED→GREEN，55+5通过，iOS构建通过 |
| S2 一天的节奏 | TIMELINE-001～005 | 5 | RED→GREEN，60+5通过，iOS构建通过 |
| S3 睡眠与趋势 | SLEEPUI-001～004、TREND-001～002 | 4 | RED→GREEN，64+5通过，iOS构建通过 |

## 复审与截图检查（C1）

代码、测试、文档三路独立复审均已返回，发现全部处置，见design-adjustments.md：

- 代码：电量覆盖不足/过期仍画曲线、缓存昨日报告无日期（ADJ-004）；真实数据清醒/未知泳道为空（ADJ-006）；无记录清醒显示0（ADJ-007）；时间按设备时区格式化（ADJ-009）；跨睡眠桶HRV行被隐藏（ADJ-005）；单点电量段不可见（ADJ-003）。
- 测试：补强方向/负号/差值取整、sourceConflict与hrOnly组合、键名检查、午后小睡、夏令时、负荷均值、重复日与NaN；TIMELINE-001改为对照c515ff6的数值与顺序校验和。
- 文档：Gate 2决策3的依据与代码不符（ADJ-005，需用户复核）；负荷均值语义（ADJ-008）；VoiceOver补截至时间。
- 截图：在东八区模拟器显示UTC合成报告，发现横轴08→05、星期为英文、主睡眠07:00–15:00、分钟“0”，修正后复拍确认为00→21、周三…周二、23:00–07:00。

截图由gitignored的simulator-only宿主渲染生产视图（仅替换@main、初始趋势与滚动锚点），保存在work/insights-screens，未提交，也不替代仓库docs/screenshots。

## 失败模式与经验

逐项见failure-modes.md。新增经验EXP-20261022-004（固定分析时区被设备时区格式化）。

## 已知缺口

- 真机未验证：真实HealthKit数据下的两张图、贡献行、睡眠详情和7日切换需用户在iPhone上查看。
- VoiceOver只做了标签静态审阅，未在模拟器或真机开启VoiceOver实测。
- docs/screenshots/iphone.png仍为旧首页，docs/validation.md与README解释行未更新：放在Deliver阶段。
- 压力HRV行只显示方向（ADJ-005），是否改为显示数值待用户决定。
- CI结果以PR检查为准；本地通过不等于远端通过。
