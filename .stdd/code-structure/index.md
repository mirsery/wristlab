# 项目代码结构索引

## 手机今日关怀（2026-10-24，人工范围索引）

- Core PhoneCarePresentation：只消费现有估算与显式时钟，状态图标/短句、连续电量及缺失/过期优先，不改评分。
- iOS PhoneCareViews / PhoneDashboardView：原位三卡、大字体单列、无分数辅助标签，生产展示时钟不触发健康读取。
- iOS MetricDetailView：复用生产详情，保留有效数值/依据、区分观测与报告时间；缺失/过期不伪造数值。
- Tests/Apple PhoneCareHost / PhoneCareUITests 与 scripts/test-phone-care.py：合成隔离宿主、完整 App 窄屏冒烟，测试环境恢复用真实前后台状态断言。

structure merge 未找到上游 delta，人工补充本轮关系，不宣称全仓库自动结构扫描。详见[交付记录](../archive/2026-10-24-phone-today-care/delivery.md)。

> 自动生成 | STDD V2.8

## Watch日常关怀（2026-10-24，人工范围索引）

上游structure merge仍寻找根changes/，未识别.stdd/changes/；未修改上游。此处人工合并本轮模块关系，不包含其他未提交变更：

- Core WatchCare：纯状态图标、活动/心情/关怀模型、趋势来源与时效验证。
- WatchSupport WatchCareModel：显式活动连接、私有保存与已提交展示投影；WatchReportModel协调来源/清除。
- Storage CareStateStore / WatchDisplayStore：私有当天心情、活动缓存和无心情原子共享包。
- watchOS DailyActivityReader：主动只读系统统计与摘要；WatchCareViews / Runtime / App消费模型。
- Widgets：原kind兼容、新活动路由，仅读取已提交包。

详见[交付记录](../archive/2026-10-23-watch-daily-care/delivery.md)。不是全仓库自动结构扫描。

## 本轮已验收故障修复（2026-10-24，人工范围索引）

- watchOS DailyActivityReader：summaryDateComponents从同一个AnalysisClock明确携带Gregorian calendar与时区，输入真实HealthKit活动摘要谓词；原系统日不变。合成日期SDK探针与真机启动/切页反馈分开。
- iOS DashboardModel：模型持有单个健康任务，首await前阶段/互斥、普通请求合并、强制连接和旧运动重读保留；显式停止/清除取消并以generation/revision拒绝晚结果。原仓库路径与权限白名单不变。
- iOS SettingsView / PhoneDashboardView：在实际连接入口附近展示状态及忙碌，设置保持原输入/弹层；页面消费模型，不直接读HealthKit。
- Tests/Apple及scripts：14个实际DashboardModel合成函数、4个生产设置视图真实点击UI、原3日期SDK契约；HealthKit合成替身/隔离宿主不代表完整App导航或真实授权通过。

归档前structure merge缺delta的原始日志分别为work/calendar-deliver-structure.log和work/phone-deliver-structure.log，未修改上游或扩展全仓库索引。详见[Watch交付](../archive/2026-10-24-watch-activity-calendar-crash/delivery.md)和[手机交付](../archive/2026-10-24-phone-health-connection/delivery.md)。

