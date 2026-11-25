# 手机健康连接 v1 测试方案

> 日期：2026-10-24；PHC-REQ-001，PHC-001至007；Gate 2用户已实际确认，Gate 3待验收。

## 一、测试策略

### 1.1 测试金字塔

生产DashboardModel控制流的隔离合成测试优先，使用可挂起/失败的适配器与临时真实仓库，验证状态及提交，不只测试另写状态机。实际iOS/HealthKit适配器由Apple构建与单独真机验收覆盖，合成替身不证明真实权限可读。

### 1.2 测试原则

- 不导出真实样本、不授权、不写健康、不操作真机清除；临时合成仓库在测试后回收。
- 第一轮保存生产行为RED，修后相同触发GREEN；不把界面状态变化当作真实数据恢复。

### 1.3 已有测试资产

| 测试文件 | 用例数 | 类型 | 覆盖范围 |
|----------|--------|------|----------|
| 既有Core与workspace | 231 | 合成回归 | 仓库/评分/Watch等既有保护，修前记录 |
| work/phone-health-probe/run.py | 2个诊断模式 | 生产控制器隔离RED | 挂起授权无反馈；调用者取消传入读取 |

## 二、详细测试案例

### 手机连接与刷新生命周期

对应PHC-REQ-001，14个生产控制器合成函数覆盖001至006；007真机验收未由合成测试证明。正式RED、GREEN及夹具修正见阶段报告。

| 字段 | ID / Spec | 预置与动作 | 预期断言 | 优先级 / 状态 |
| --- | --- | --- | --- | --- |
| **ID** | TC-PHC-001 / PHC-001 | 合成authorize挂起，连续两次connect；生产设置视图实际滚动点击 | 首个await前状态变化、busy=true，authorize仅一次；设置按钮旁有状态/忙碌且防重，演示禁用真实连接 | P0 / 14模型回归及4设置UI GREEN，设备另验 |
| **ID** | TC-PHC-002 / PHC-002 | 调用者取消，读取有受控挂起和正常完成 | 共享读取不被调用者取消，结果正常提交且不误报刷新已取消 | P0 / 合成GREEN |
| **ID** | TC-PHC-003 / PHC-003 | 并发前台/刷新/观察，授权期间普通刷新 | 仅一查询；连接force及旧运动重读不丢失；后续观察至多合并一次；失败无无限重试 | P0 / 合成GREEN |
| **ID** | TC-PHC-004 / PHC-004 | 临时文件先损坏/不可读，再人工修复合成文件后重试 | 首次明确反馈且原文件字节不变，恢复后连接可用 | P0 / 合成GREEN |
| **ID** | TC-PHC-005 / PHC-005 | 读取挂起时对合成仓库停止/清除，再放行非空且忽略取消的晚回调 | 不复活记录、读取开关、report/anchor，不后台重启；显式取消仍执行 | P0 / 合成GREEN |
| **ID** | TC-PHC-006 / PHC-006 | 预存合成报告/计划后授权失败/读取失败；另测空结果再重试 | busy释放、失败保留旧数据和anchor/计划，空结果中性，后续可重试 | P0 / 合成GREEN |
| **ID** | TC-PHC-007 / PHC-007 | 手机同包覆盖后核对真实版本，从实际设置入口点击连接 | 2403用户明确设置入口仍无反馈，故待2404真实复验；不据安装或合成声称健康已读或Watch更新 | P0 / 2403反馈失败，2404待真机 |

原行为诊断命令已运行：`python3 work/phone-health-probe/run.py`与追加`cancellation`，均退出1；日志只含合成布尔状态。正式回归`python3 scripts/test-phone-health.py`已接入scripts/check.sh，14函数GREEN见work/phone-health-probe/green-review-fixed.log。

S2 UI命令：`python3 scripts/test-settings-connection.py`；隔离iOS宿主直接嵌入生产SettingsView及生产DashboardModel、只用合成适配器。4个XCTest函数为testSettingsWaitingFeedback、testSettingsReadAndEmptyResult、testSettingsFailureFeedback、testSettingsDemoCannotConnect（后缀对应001/006）。原设置实际点击后等待状态缺失、按钮仍enabled且无忙碌标签，RED见work/settings-connection-ui-red.log；补按钮同组状态、busy防重后4项GREEN见work/settings-connection-ui-green.log，已纳入build-apple.sh。无真实授权、不覆盖首页到sheet的完整导航、不证明实际样本可读。

## 三、测试执行矩阵

| 功能模块 | 单元测试 | 集成测试 | E2E | 状态 |
|----------|---------|----------|-----|------|
| 生产手机控制器 | 001至006共14函数GREEN | 临时仓库与可控适配器 | 007人工设备复验 | 设备另验 |
| 原业务/同步 | 全量check.sh | 原事务/快照测试 | 不扩大范围 | 修后重跑 |
| iOS/Watch App | SDK构建 | 原3日期与组件注册 | 真机分开 | 修后build-apple.sh |

## 四、回归风险矩阵

| 风险区域 | V<版本> 改动 | 已有回归保护 | 风险等级 |
|----------|-------------|-------------|---------|
| 取消与重入 | 单任务、显式取消及代次 | 需补生产控制器回归 | 中 |
| 原缓存与手动计划 | 只重试打开，不迁移 | 原仓库事务测试+004/006 | 中 |
| 授权与缺失 | 仅原只读类型、不推断拒绝 | 001/006加真实用户复验 | 中 |
| 评分/云/Watch连接 | 无变更 | 全量原回归；连接阻塞另记 | 低 |

## 五、建议补充顺序

1. Gate 2后按反馈/任务生命周期小切片先RED再修复GREEN。
2. 全量check.sh和build-apple.sh，失败模式与只读审查，记录偏差。
3. 手机2403签名/同包安装/版本核对和用户状态反馈；Gate 3由用户真实验收。
