# 手机今日关怀卡片对齐与顶部状态栏遮挡修复设计

## Context
2405 真机截图（不入库，不记录其数值）：身体电量卡为多行长校准说明，生理压力卡为短状态，两卡上下错位；顶部滚动后页头文字在状态栏时间后方半透明可见。

已在 iPhone 18 Pro Max 模拟器（与真机同为 440×956pt）用合成 `--demo` 复现，证据在 `work/care-layout/`：
- 错位根因：`PhoneCareSection` 的两列 `LazyVGrid` 未指定 `GridItem.alignment`，行内单元格默认垂直居中，矮卡被下推 (高差/2)。合成数据下两卡顶边差 7pt（187.3 vs 173.7pt 高）；长校准说明下差值放大，与真机截图一致。
- 顶部根因：今天页 `.toolbar(.hidden, for: .navigationBar)`，没有导航栏背板；滚动后内容进入状态栏区，只剩系统 iOS 26 软边缘模糊，文字与时钟叠在一起。其他页签有内联导航栏，不受影响。滚动位置在切页签、30 秒 TimelineView 刷新后保持不变，排除 `scrollPosition` 回跳。
- 底部：滚动到底时最后一张卡（报告日活动）完整位于浮动页签栏上方；滚动中内容从页签栏下方经过是系统 Liquid Glass 的正常表现，不改。

## Decisions
1. **两列等高、内容顶对齐（推荐）**：标准字号下用 `HStack(alignment: .top)` + `.fixedSize(horizontal: false, vertical: true)`，两卡 `.frame(maxHeight: .infinity, alignment: .topLeading)` 填满行高，「查看详情」用 `.frame(maxHeight: .infinity, alignment: .bottomLeading)` 贴底（不用 Spacer，避免 VStack 间距让全宽准备度卡多出 12pt），卡片标题加纵向 `fixedSize` 防止定高后被压缩。辅助字号保持现有单列。文本不截断、不缩写，说明全文保留。
   - 备选 A：仅顶对齐（`GridItem(.flexible(), alignment: .top)`），改动最小，但两卡底边仍参差。
   - 备选 B：任一卡为长校准/缺失说明时整组改单列，阅读更舒展，但布局随数据状态跳变，并需新增展示规则。
2. **今天页状态栏不透明背板（推荐）**：仅今天页加一条与页面同色（`wristBackground`）的状态栏背板，滚入顶部的内容被干净遮住；实现只用 iOS 17 起可用的 API，但实测仅 iOS 27.0 模拟器。背板 `allowsHitTesting(false)` + `accessibilityHidden(true)`；VoiceOver 不聚焦只经代码审查，未自动验证。
   - 备选 A：iOS 26+ 用 `.scrollEdgeEffectStyle(.hard, for: .top)`，系统风格但 iOS 17–25 不变。
   - 备选 B：今天页恢复内联导航栏「今天」，与现有品牌页头重复。
3. 不改 `PhoneCarePresentation`、评分、有效期、文案、路由或页签；只改布局。

## Architecture
`PhoneDashboardView.page(.today)` → 顶部背板（新增，仅 today）→ `ScrollView` → `PhoneCareSection` → 标准字号：等高双列 / 辅助字号：单列 `PhoneCareCard`。测试宿主 `PhoneCareHost` 直接复用 `PhoneCareSection`，新增合成夹具 `--mixed-heights`（电量校准 9/14 合成天数 + 压力短状态）。

## Risks / Trade-offs
| 风险 | 缓解措施 |
|------|----------|
| 等高后短卡出现留白 | 内容顶对齐、详情入口贴底，留白在说明与入口之间；Gate 2 可改选备选 B |
| `fixedSize` 双列在长文本下高度计算错误导致截断 | UI 断言两卡等高且无障碍标签含全文；截图人工核对 |
| 背板颜色与页面背景不一致产生色带 | 使用同一 `wristBackground` 常量；截图核对 |
| 遮挡判定难以用元素断言表达 | 截图像素检查状态栏区域是否为纯背景色，并人工核对截图；真机由 Gate 3 用户确认 |

本轮与 `2026-10-24-watch-refresh-exit` 合并构建 2406，同包覆盖安装两端，不卸载、不清数据、不开 iCloud。
