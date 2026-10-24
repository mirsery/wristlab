# 当前阶段：Spec草稿，等待Gate 2

Gate 1：上一轮展示综合周报范围并询问进入设计后，用户回复“可以”；CLI已记录原文及上下文。只批准综合周报，习惯日记、作息提醒和体重自动读取未纳入。Gate 2未确认，Build pending；不写业务代码、不操作真机。

标准模式，初步复杂度7（文件2/行数2/能力1/风险1/数据接口1/安全0），单一展示能力；估算不是运行指标。无跨系统/权限/云变更，锚定L2，复用PlanningState、WorkoutCompletion与AnalysisClock接口。

设计草稿：本周周一至昨天对比上周同星期；上周完整周对比再前周。睡眠/体重各≥3有效日；执行证据分开、去重、休息优先；今天一张摘要、趋势二级入口；下一步最多3项只导航。周一空窗和周期需Gate 2确认。

产出：canonical proposal、design.md、10场景spec、agent验证规格、test-plan.md。根specs权威条目待Gate 2后、实现前更新，避免草稿冒充批准。

CLI限制：extract-proposal把capability读为空，以canonical核对1个能力；experience list缺requests，手工读取007/008并纳入状态/日期来源失效，不修改上游或安装依赖。验证只记录实跑结果。

设计阶段检查：canonical/Human View/TC逐项映射5需求、10场景、10唯一TC，通过；每场景AND至多2。CLI validate已通过但按整份文件累计11个AND而警告超过5，人工逐场景确认不超限，不改上游或删有效约束规避告警。初次test-plan表格未被CLI的**ID**计数器识别，已改为模板的逐案例ID表后通过。

scripts/check.sh初次在沙箱内因Swift模块缓存不可写退出1（work/integrated-weekly-review-spec-check.log）；经升级权限重跑退出0（work/integrated-weekly-review-spec-check-final.log），既有185 Core+25 workspace共210项回归通过。新周报尚无业务代码或测试，这210项不证明新功能已实现。project-check、根规格/链接检查、git diff --check均通过；本轮仅文档，未运行Apple app构建，也未安装/启动/查询实体设备。Gate 2继续待用户确认，不批准Build或Gate 3。
