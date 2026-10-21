# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
Core判定与文案用合成报告单测；通知授权与投递为平台适配，以构建与真机验收为证据。

## 详细测试案例

### SC-BRIEF-001 — 是否发送

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-BRIEF-001 |
| **对应 Spec** | morning-brief/spec.md → Scenario: SC-BRIEF-001 |
| **优先级** | P0 |
| **预置条件** | 真实报告分别为：今天且有已完成主睡眠、今天已发过、今天无主睡眠、非今天的报告、演示来源；时刻为05:00前、05:00、14:00前与14:00；非UTC分析时区 |
| **输入** | 判定晨报 |
| **预期结果** | SHALL 只有今天、真实、有已完成主睡眠、在05:00（含）至14:00（不含）且未发过时返回通知，其余为空；已发记录按分析日（固定时区）比较 |
| **测试函数** | morningBriefSendsOncePerDayAfterMainSleep_TC_BRIEF_001 / morningBriefWindowMainSleepAndMarks_TC_BRIEF_002 |
| **层次** | Swift Testing Core单元 |

### SC-BRIEF-002 — 通知内容

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-BRIEF-002 |
| **对应 Spec** | morning-brief/spec.md → Scenario: SC-BRIEF-002 |
| **优先级** | P0 |
| **预置条件** | 准备度有值、日间回退、部分估算、校准中、过期，含小睡的睡眠窗口，以及隐藏数值开关 |
| **输入** | 生成晨报文案 |
| **预期结果** | SHALL 显示准备度数值与002分段（并标日间或部分估算）或具体缺失原因，以及主睡眠时长（不含小睡）；隐藏数值时不含任何数值或原因；不含训练或健康建议 |
| **测试函数** | morningBriefTextShowsValueOrReasonAndHides_TC_BRIEF_002 / morningBriefWindowMainSleepAndMarks_TC_BRIEF_002 |
| **层次** | Swift Testing Core单元 |

### SC-BRIEF-003 — 设置与投递

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-BRIEF-003 |
| **对应 Spec** | morning-brief/spec.md → Scenario: SC-BRIEF-003 |
| **优先级** | P1 |
| **预置条件** | 设置页晨报开关与隐藏数值开关，真机 |
| **输入** | 开启、拒绝授权、系统事后关闭通知、前台与后台刷新、清除数据 |
| **预期结果** | SHALL 开启时请求授权，拒绝或被关闭时在设置页说明；满足条件的真实刷新后投递一次（前台也显示）；清除数据撤回已送达晨报 |
| **测试函数** | —（真机验收） |
| **层次** | 真机/人工 |

## 测试执行矩阵

| 场景 | Capability | 层次 | 优先级 |
| --- | --- | --- | --- |
| BRIEF-001 | morning-brief | Swift Testing Core单元 | P0 |
| BRIEF-002 | morning-brief | Swift Testing Core单元 | P0 |
| BRIEF-003 | morning-brief | 真机/人工 | P1 |

## 回归风险矩阵

| 改动区域 | 风险 | 回归手段 |
| --- | --- | --- |
| DashboardModel刷新路径 | 低：重复通知 | 按天去重；单测 |
| 设置页 | 低 | 静态检查 |

## 建议补充顺序

P0：BRIEF-001～002；P1：BRIEF-003。
