# 设计调整

1. 详情入口贴底由 `Spacer(minLength: 0)` 改为 `.frame(maxHeight: .infinity, alignment: .bottomLeading)`：Spacer 在 VStack 中额外占一个 12pt 间距，使全宽准备度卡变高；截图核对后修正。卡片标题补纵向 `fixedSize`（代码评审 P2，定高行内防压缩）。行为语义不变。
2. PCL-003「背板不进入无障碍树」无法用 XCUITest 断言：带标识的容器即使 `accessibilityHidden(true)` 仍出现在 XCUITest 树中。改为断言背板几何覆盖状态栏、不可点击，并在采样前确认内容位于采样带下；VoiceOver 不聚焦仅代码审查，列为手工未验项。规格措辞改为「对 VoiceOver 隐藏」。
3. 夹具天数由与真机截图相同的值改为合成 9/14，遵守不复制真实健康数值的约束（文档评审 P1）。
4. 正式 App 用例（003/004）不在 `build-apple.sh` 门禁内，需 `--full-app` 显式运行，已写入测试方案。
