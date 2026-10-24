# 失败模式核查

1. 范围：只改 PhoneCareViews 布局、page(.today) 背板、测试宿主/用例/runner；展示模型、文案、评分未改。
2. 复现：修前 UI 断言真实失败（66pt 错位、像素偏差 26），非编译失败。
3. 假绿：PCL-003 先断言内容位于采样带下，两次背板变异均失败；002/004 修前即通过，已标注为回归保护。
4. 截断：标签来自展示模型，渲染不截断靠截图人工核对，未自动化。
5. 辅助字号：保留单列分支，002 覆盖。
6. 滚动/刷新：背板零高度、spacing 0，scrollPosition 与 refreshable 原用例通过。
7. 其他页签：背板仅 today；完整 App 五页签冒烟通过。
8. 无障碍：allowsHitTesting(false)+accessibilityHidden(true)；VoiceOver SKIPPED（手工未验）。
9. 隐私：夹具改合成 9/14；真机截图不入库、不记数值。
10. 设备差异：采样带假定面容 ID；Home 键机型 SKIPPED。
11. 构建/签名：2406 无 iCloud 权限，签名严格校验通过，个人 team 仅命令参数。
12. 数据：同包覆盖，未卸载/清数据/开 iCloud。
