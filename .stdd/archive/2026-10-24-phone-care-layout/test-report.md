# 手机今日关怀布局修复验证报告（待 Gate 3）

日期：2026-10-24。范围 PCL-001–004。未提交、未推送。

## 行为变化
- 标准字号下电量/压力两卡顶边对齐、等高，「查看详情」贴底；辅助字号仍单列。文案、评分、路由不变。
- 今天页（隐藏导航栏）状态栏加同色背板，滚动内容不再透到时钟后；其他页签不变。

## 实际检查
| 检查 | 结果 | 证据 |
|------|------|------|
| RED | PCL-001 顶边 391 vs 457pt；PCL-003 状态栏偏差 26 > 4 | work/care-layout/ui-red-host.log, ui-red-fullapp.log |
| GREEN 宿主 | PCL-001/002 通过（002 修前即通过，作回归保护） | work/care-layout/ui-green3.log |
| GREEN 正式 App | PCL-003/004 + 原 PTC 冒烟通过（iPhone 18 Pro Max / iOS 27.0 模拟器） | work/care-layout/ui-green4-fullapp.log |
| 变异 | 背板改透明 / opacity 0 两次均被 PCL-003 拦截 | work/care-layout/ui-mutant-*.log |
| scripts/check.sh | 通过，207 Core + 35 Workspace + 14 手机模型 = 256 | work/fix-2406-check2.log |
| scripts/build-apple.sh | 退出 0：双端构建、组件注册、设置 UI 4、关怀宿主 UI 12 | work/fix-2406-apple.log（评审修正前一次；修正后宿主/正式 App 用例已单独重跑） |
| 真机 | 2406 签名（无 iCloud 权限）同包覆盖 iPhone，版本 2406，普通启动；用户反馈「手机布局也好了」 | work/fix-2406-phone-install.log, fix-2406-phone-launch.log |

截图已人工核对：等高双列、准备度卡高度不变、状态栏干净（work/care-layout/final-shots/）。

## TC 追溯
| TC | 测试 |
|----|------|
| TC-PCL-001 | testMixedHeightCardsAlign_TC_PCL_001 |
| TC-PCL-002 | testLargestTypeMixedHeightsStack_TC_PCL_002 |
| TC-PCL-003 | testScrolledContentStaysOutOfStatusBar_TC_PCL_003（--full-app） |
| TC-PCL-004 | testLastTodayCardClearsTabBar_TC_PCL_004（--full-app） |

## 评审
代码评审：无 P0/P1；P2 标题定高压缩风险已加 fixedSize。测试评审：P2 采样带依赖设备、内容未必在采样带下、无障碍断言空洞、002 截图/电量导航缺失、004 未确认到底——均已修正。文档评审：P1 夹具沿用真机天数已改合成 9/14；P1 VoiceOver 无验证已记为偏差；描述不一致已同步。详见 design-adjustments.md。

## 未验项
- VoiceOver 不聚焦背板仅代码审查；最大字体之外的 xxxLarge 窄屏未截图核对。
- 采样带 x 32–64% 假定面容 ID 机型；Home 键机型未运行。
- 正式 App 用例不在 build-apple.sh 门禁内，需 --full-app 显式运行。
- 仅 iOS 27.0 模拟器 + 用户一台 iPhone 实测；iOS 17–26 未运行。
