# 测试计划（Gate 1/2已确认，实施中）

## 测试策略
Core解码与时间线用合成快照单测；小组件配置用独立宿主运行注册检查；外观用模拟器渲染截图；真机添加与系统刷新由用户验收。

## 详细测试案例

### SC-PHONEW-001 — 快照缓存校验

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PHONEW-001 |
| **对应 Spec** | phone-widgets/spec.md → Scenario: SC-PHONEW-001 |
| **优先级** | P0 |
| **预置条件** | 有效真实快照、演示快照、损坏JSON、超过64KB、未知schema与清除标记快照 |
| **输入** | 小组件读取phone-snapshot.json |
| **预期结果** | SHALL 只接受有效真实快照与清除标记，其余视为无快照（等待手机）；无文件时同样为等待状态 |
| **测试函数** | phoneWidgetCacheAcceptsOnlyRealSnapshots_TC_PHONEW_001 |
| **层次** | Swift Testing Core单元 |

### SC-PHONEW-002 — 显示与时间线

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PHONEW-002 |
| **对应 Spec** | phone-widgets/spec.md → Scenario: SC-PHONEW-002 |
| **优先级** | P0 |
| **预置条件** | 快照含当前、部分、过期与缺失的指标 |
| **输入** | 生成组件时间线与各指标显示 |
| **预期结果** | SHALL 每个指标按ComplicationPresentation显示数值或原因，时间线包含现在与各指标失效时刻且不含过去时刻；清除标记显示数据已清除且无数值 |
| **测试函数** | phoneWidgetTimelineAndStatesFollowSnapshot_TC_PHONEW_002 |
| **层次** | Swift Testing Core单元 |

### SC-PHONEW-003 — 注册与外观

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PHONEW-003 |
| **对应 Spec** | phone-widgets/spec.md → Scenario: SC-PHONEW-003 |
| **优先级** | P0 |
| **预置条件** | iPhone小组件扩展的生产配置 |
| **输入** | 在独立宿主中执行配置body |
| **预期结果** | SHALL 每个配置输出成功标记，无fatal |
| **测试函数** | scripts/test-widget-registration.py --platform ios |
| **层次** | 运行检查（build-apple.sh注册宿主） |

### SC-PHONEW-004 — 注册与外观

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PHONEW-004 |
| **对应 Spec** | phone-widgets/spec.md → Scenario: SC-PHONEW-004 |
| **优先级** | P1 |
| **预置条件** | 小/中、圆形、矩形、行内五种尺寸，有快照与无快照 |
| **输入** | 渲染 |
| **预期结果** | SHALL 数值、原因与更新时间可辨，锁屏视图标记隐私敏感 |
| **测试函数** | —（模拟器渲染截图） |
| **层次** | 模拟器/人工 |

## 测试执行矩阵

| 场景 | Capability | 层次 | 优先级 |
| --- | --- | --- | --- |
| PHONEW-001 | phone-widgets | Swift Testing Core单元 | P0 |
| PHONEW-002 | phone-widgets | Swift Testing Core单元 | P0 |
| PHONEW-003 | phone-widgets | 运行检查（build-apple.sh注册宿主） | P0 |
| PHONEW-004 | phone-widgets | 模拟器/人工 | P1 |

## 回归风险矩阵

| 改动区域 | 风险 | 回归手段 |
| --- | --- | --- |
| iOS应用新增App Group与扩展 | 中：签名与安装 | 构建；真机安装由Xcode重新生成配置 |
| DashboardModel写缓存 | 中：演示泄漏 | 只在真实快照路径写入；单测拒绝演示 |
| CI时长 | 中：超时 | 调整timeout-minutes |

## 建议补充顺序

P0：PHONEW-001～003；P1：PHONEW-004。
