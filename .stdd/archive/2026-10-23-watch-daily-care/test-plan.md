# Watch日常关怀版测试方案（Gate 2批准基线）

> 2026-10-23制定；9需求、15场景/15TC。以下“待写”等为Gate 2时计划快照，不代表当前进度；2026-10-24实际执行结果、21项新增测试与平台缺口见test-report.md。

## 一、测试策略

### 测试金字塔与原则

Core纯状态/分段/日期/关怀规则 → 实际本地store与协调器故障注入 → 双端构建/五种既有及新增组件注册 → Watch模拟器尺寸/字体/单色/滚动。真机健康授权、系统实际汇总、断连与表盘刷新另记，不拿合成预览证明。

只用合成数据；显式时钟、日期/来源/演示代次。thorough范围按切片TDD与失败模式复查，不表示Gate 2/3已批准。测试名带TC_WCP_001等标记；每个TC至少一项新增生产路径测试；UI场景保留人工模拟器证据，不只测DTO。

### 已有资产

| 资产 | 保护范围 | 新缺口 |
| --- | --- | --- |
| Physiology/Business金例与边界测试 | 原压力/准备度公式、14日/15分钟 | 图标/标签/情境映射 |
| WatchReportModelTests / WatchDisplayStoreTests | 主动读取、原子投影、失败重试、清除耐久 | 新活动/心情状态及投影 |
| ComplicationPresentation/WatchDisplay测试 | 过期/缺失/producer/模式 | 无分数布局与活动kind |
| build-apple及Widget注册脚本 | 原四Watch/一iPhone配置 | 新kind注册与图标实际渲染 |

## 二、详细测试案例

### 图标化关怀与压力展示

#### WCP-001

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCP-001 |
| 对应Spec / 优先级 | watch-care-presentation/WCP-001 / P0 |
| Arrange / Act | 0/19/20/59/60/79/80/100压力，32/33/66/67准备度、真实0电量及未记录心情；构建展示模型 |
| Assert | 边界映射准确，无原始评分标签/朗读；未记录为中性图标；不新增电量档位或修改评分版本 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCP-002

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCP-002 |
| 对应Spec / 优先级 | watch-care-presentation/WCP-002 / P0 |
| Arrange / Act | 13/14日、无HR、15分钟边界、未来、activity+高值、HR-only；本地与手机贡献差异 |
| Assert | 优先状态/情境正确；手机无贡献说明缺失；不诊断焦虑、不伪造HRV |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCP-003

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCP-003 |
| 对应Spec / 优先级 | watch-care-presentation/WCP-003 / P0 |
| Arrange / Act | 有效/缺失/HR-only/运动交替桶、选中源切换、异profile、7日步数缺口与今天 |
| Assert | 分段/缺口/时间和标签正确；手机无图提示；不从三个分数画平线 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCP-004

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCP-004 |
| 对应Spec / 优先级 | watch-care-presentation/WCP-004 / P1 |
| Arrange / Act | 长中文原因、全部页/菜单路由、不同模拟器尺寸/字号及来源切换 |
| Assert | 模型路由先测；模拟器逐页滚动/VoiceOver另记；编译不作UI通过 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCP-005

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCP-005 |
| 对应Spec / 优先级 | watch-care-presentation/WCP-005 / P0 |
| Arrange / Act | 旧kind注册与路由、四种尺寸、活动0/未知/过期、单色及隐私遮盖 |
| Assert | 旧kind可注册无重命名；新路由/字段隔离；布局需模拟器证据，系统添加需后续真机 |
| 当前状态 | 待写测试/待实现/待验证 |

### 手表日常活动只读事实

#### WDA-001

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WDA-001 |
| 对应Spec / 优先级 | watch-daily-activity/WDA-001 / P0 |
| Arrange / Act | fake reader记录调用，未连接启动/切页/主动连接；步骤与摘要分别空/失败 |
| Assert | 主动前0新增query，读类型白名单/无share；评分/另一分项不被失败阻断 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WDA-002

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WDA-002 |
| 对应Spec / 优先级 | watch-daily-activity/WDA-002 / P0 |
| Arrange / Act | 注入0/nil/负/NaN/未来/重复日期统计，检查生产adapter统计options与日界 |
| Assert | 0与未知分开、7日界限及今日进行中；不含样本手动相加路径 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WDA-003

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WDA-003 |
| 对应Spec / 优先级 | watch-daily-activity/WDA-003 / P0 |
| Arrange / Act | energy/time/unknown模式、nil/0/负目标、超额值、paused和旧系统 |
| Assert | kcal/min/h单位和比率准确；不自动填30/12、不催补 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WDA-004

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WDA-004 |
| 对应Spec / 优先级 | watch-daily-activity/WDA-004 / P0 |
| Arrange / Act | 上海与纽约的不同当前日、午夜前后、DST日；旧日期cache |
| Assert | 两个日期标签/区间独立、旧当日不显示为当前、无评分重配置 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WDA-005

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WDA-005 |
| 对应Spec / 优先级 | watch-daily-activity/WDA-005 / P0 |
| Arrange / Act | fake reader控制一项成功、一项失败、重叠请求、取消后回调、60分钟边界及跨日 |
| Assert | 分项结果/旧缓存时间准确；晚回拒绝、终态与busy一致；无额外后台注册 |
| 当前状态 | 待写测试/待实现/待验证 |

### 本机心情与关怀状态

#### WCS-001

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCS-001 |
| 对应Spec / 优先级 | watch-care-state/WCS-001 / P0 |
| Arrange / Act | 5标签、未记录/取消/确认/改/删，低生理压力+低落心情 |
| Assert | 字典/保存状态正确，两者并列无互相覆盖，输入评分不变 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCS-002

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCS-002 |
| 对应Spec / 优先级 | watch-care-state/WCS-002 / P0 |
| Arrange / Act | 真实临时store注入写失败/损坏/重开，假时钟跨日，演示代次/时区变化 |
| Assert | 无旧记录复活、失败不覆盖旧文件；组件投影无心情字段 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCS-003

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCS-003 |
| 对应Spec / 优先级 | watch-care-state/WCS-003 / P0 |
| Arrange / Act | 各分支同时命中、压力HR-only/运动/过期、暂停目标完成、无数据与心情低落 |
| Assert | 确定性优先级/事实来源正确，无虚假赞美、责备或外部副作用 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCS-004

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCS-004 |
| 对应Spec / 优先级 | watch-care-state/WCS-004 / P0 |
| Arrange / Act | 实际WatchDisplayStore注入writer失败与重开；旧包迁移，40KB边界、选源与revision错配 |
| Assert | 旧字段/模式保留、发布原子、源隔离、可重试、容量有界无演示落盘 |
| 当前状态 | 待写测试/待实现/待验证 |

#### WCS-005

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-WCS-005 |
| 对应Spec / 优先级 | watch-care-state/WCS-005 / P0 |
| Arrange / Act | 标记写失败、分步清理失败、晚query/保存、真实文件重开及phone clear |
| Assert | 两级清除作用域/耐久标记/错误优先级准确，无手机原始或本地非目标误删 |
| 当前状态 | 待写测试/待实现/待验证 |

## 三、测试执行矩阵

| 功能 | 单元/集成 | 模拟器 | 真机 |
| --- | --- | --- | --- |
| 图标/压力/图表 | WCP001–003、005，待写 | 布局/注册/路由待验 | 暂未执行 |
| 主动活动/日期/目标/失败 | WDA001–005，待写，实际adapter本地SDK编译核对 | 系统无真实数据只测空/合成态 | 真实授权、计数/暂停/同步差异待验 |
| 心情/关怀/存储/清除 | WCS001–005，待写，实际store故障/重开 | 日期/取消/演示交互待验 | 本机保存及锁屏待验 |
| 字体/滚动/VoiceOver/单色 | WCP004及005路由规则待写 | 小/大屏/辅助字号/减动态待验 | 系统表盘待验 |

## 四、回归风险矩阵

| 区域 | 风险 | 验证 |
| --- | --- | --- |
| 压力模型 | 展示变更误改分段/缺失或隐含心理判断，高 | 原金例数值不变+WCP边界与情境 |
| 读取/系统日期 | 额外权限、重复统计、跨日过期，高 | WDA主动前无调用、部分失败、DST/暂停 |
| 私有心情/原子投影 | 数据外泄/失败复活，高 | WCS共享包字段白名单、写失败/停止/重开 |
| 旧手机模式/组件 | 新字段兼容或旧kind丢失，中 | 旧schema恢复、旧kind注册/URL |
| 版式 | 小字/遮挡/单色无法理解，中 | Watch模拟器视觉与VoiceOver单独记录 |

## 五、建议补充顺序

1. P0：WCP001/002状态字典、WDA输入与日期模型、WCS心情/关怀规则，分别RED/GREEN。
2. P0：活动adapter和本机store、WCS004/005投影与隐私清除，真实故障/重启测试。
3. P0/P1：三页/图表/组件整合，完整scripts/check.sh与scripts/build-apple.sh，辅助字号/滚动/单色视觉。
4. Gate 3报告列明真实授权、活动目标/暂停、系统表盘/离线等未完成项；用户准备后再安装验证，不导出健康记录。

命令：./scripts/check.sh；./scripts/build-apple.sh；git diff --check；./scripts/stdd validate 2026-10-23-watch-daily-care；./scripts/stdd --project-check。上游Python-only TC扫描或AND整文件累计警告如仍存在，保留原始结果并提供Swift/逐场景追溯，不伪造通过。

Gate 2已实际确认；本文件仍是批准的计划基线，不是完整场景全部通过的报告。用户随后确认Gate 3代码/模拟器阶段与已披露缺口，证据见.stdd.yaml和test-report.md，平台未测项仍未通过。
