# 失败模式检查（standard：a–l）

2026-10-22，对照本change的diff、执行证据与经验库逐项检查。

| 类别 | 结果与证据 |
| --- | --- |
| a 幻觉行为 | 已查：测试数、构建与截图均有日志/文件；未把模拟器截图写成真机验证。 |
| b 范围蔓延 | 已查：Watch、同步schema、公式、HealthKit类型未改；ADJ-001/002/009为本次界面范围内的文案与格式修正。EnergyReport新增Optional字段已在Gate 2确认。 |
| c 级联错误 | 已查：12份数值金例与原50 Core测试全过；TIMELINE-001用c515ff6跑出的数值与顺序校验和比对，含午后小睡变体。 |
| d 上下文丢失 | 发现并修正：Gate 2所述“补键改Watch载荷”与代码不符（ADJ-005），已更正并在Gate 3请用户复核。 |
| e 工具误用 | 已查：`stdd canon generate`只渲染proposal，spec.md由同格式脚本从YAML重渲染，内容与YAML一致；validate的“AND数量”为文件级警告。 |
| f 运行时偏差 | 发现并修正：时区格式化（EXP-20261022-004）；SwiftUI类型检查超时由SleepLane非public初始化引起，已修。 |
| g 管线断链 | 已查：check.sh、build-apple.sh（含Widget注册运行检查）与git diff --check结果见test-report；CI以PR检查为准。 |
| h 内容质量偏差 | 已查：贡献只描述“推高/拉低”作用并附非医疗声明；无祈使建议；“查看原因与建议”为前一change已确认文案，指数据补充方式，未改。 |
| i 指令衰减 | 已查：无真实健康数据、签名材料；未自动批准Gate 3、未合并。 |
| j 覆盖真空 | 已查：17个Scenario均有TC；14个Core TC有测试函数，3个界面TC以模拟器截图与静态检查验证；未报覆盖率百分比（未启用）。 |
| k 契约断层 | 已查：EnergyReport旧JSON解码（TIMELINE-003）；DisplaySnapshot不含新字段；SmallMetricCard签名变化只影响iOS（watch与Widget不使用）。 |
| l 锚定缺失 | 已查：L2锚定MetricExplanation与PhoneDashboardView，新展示与过期/演示判定复用MetricExplanation（EXP-001）。 |
