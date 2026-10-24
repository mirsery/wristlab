# 手机今日关怀布局测试方案

> 创建日期：2026-10-24 · 对应 Spec：specs/phone-today-care/spec.md（PCL-001–004）

## 一、测试策略
UI 布局缺陷只能在渲染层验证：测试宿主 `PhoneCareHost` 复用生产 `PhoneCareSection`，以元素 frame 断言对齐/重叠；正式 App 以合成 `--demo` 验证状态栏与页签边界。全部合成数据，真机截图不入库。已有 254 项 Swift、15 项模拟器 UI（设置 4、关怀 10、完整 App 1）作为回归保护。

## 二、详细测试案例

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PCL-001 |
| 对应 Spec / 优先级 | PCL-001 / P0 |
| Arrange | 宿主 `--mixed-heights`：电量 `calibrating` baselineDays 9（合成，energy），压力有效短状态；标准字号 |
| Act | 读取 `care.energy` / `care.stress` frame 与无障碍标签 |
| Assert | 顶边差、高度差 ≤ 1pt（修前 RED）；电量标签含完整校准说明（标签来自展示模型，渲染不截断由截图人工核对）；两卡可点击进入对应详情 |

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PCL-002 |
| 对应 Spec / 优先级 | PCL-002 / P0 |
| Arrange | `--mixed-heights --large-type` |
| Act | 滚动定位两卡 |
| Assert | `energy.maxY ≤ stress.minY`、宽度不超屏；标签含全文；两卡均可进入详情；附截图（修前已通过，作回归保护） |

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PCL-003 |
| 对应 Spec / 优先级 | PCL-003 / P1 |
| Arrange | 正式 App `--demo`，iPhone 18 Pro Max 隔离模拟器 |
| Act | 把合成状态卡拖到状态栏下方并确认其与采样带重叠，截图 |
| Assert | 背板 frame 自屏顶覆盖状态栏（高 ≥ 20pt）且不可点击；采样带（x 32–64%，y 取背板内 4pt 内缩，面容 ID 机型）像素与 `wristBackground` 偏差 ≤ 4（修前 RED 偏差 26）；VoiceOver 不聚焦未自动验证；截图人工核对 |

| 字段 | 内容 |
| --- | --- |
| **ID** | TC-PCL-004 |
| 对应 Spec / 优先级 | PCL-004 / P1 |
| Arrange | 正式 App `--demo` |
| Act | 滚动到底并再滑一次确认位置不变；依次切换五个页签；进入训练准备度详情并返回 |
| Assert | 最后一张卡 maxY ≤ 页签栏 minY（修前已通过，作回归保护）；原 `testFullAppTodayNavigation` 断言继续通过 |

正式 App 用例（003/004 及原 PTC 冒烟）需显式 `python3 scripts/test-phone-care.py --full-app --device <隔离模拟器>`，`build-apple.sh` 不自动运行；运行前须先安装当前模拟器构建。

## 三、测试执行矩阵
| 功能模块 | 单元 | 宿主 UI | 正式 App UI | 真机 |
|----------|------|---------|-------------|------|
| 双列对齐 | — | 001 | 截图 | Gate 3 用户确认 |
| 辅助字号单列 | — | 002 | — | 未计划 |
| 状态栏背板 | — | — | 003 | Gate 3 用户确认 |
| 底部边界与导航 | — | 原 PTC 用例 | 004 | Gate 3 用户确认 |

## 四、回归风险矩阵
| 风险区域 | 本轮改动 | 已有回归保护 | 风险等级 |
|----------|----------|--------------|----------|
| 关怀卡文案/无障碍 | 不改 | PTC-001–006 宿主用例 | 🟢 |
| 辅助字号布局 | 分支保留 | LargestType 两项 | 🟢 |
| 今天页滚动位置恢复 | 背板不改 ScrollView | 完整 App 冒烟 | 🟡 |
| 其他页签导航栏 | 不改 | 完整 App 冒烟 | 🟢 |

## 五、建议补充顺序
单切片：001/003 RED → 布局与背板修复 → 001–004 GREEN → 原 15 项 UI + check.sh + build-apple.sh → 2406 同包覆盖 → Gate 3 用户真机确认。
