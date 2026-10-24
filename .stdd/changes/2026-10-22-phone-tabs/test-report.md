# 五 Tab 验证报告

## 睡眠页顶部区域修正
用户明确“睡眠这个页面”“顶部区域挡住内容”。源码确认整块pageStatus原位于List外的safeAreaInset顶部固定；本次将其作为SleepDetailView的首个Section，随列表滚动，去掉重复演示标记。对应P-004/P-010及NAV-003的小型布局调整，未改评分/健康读取。
work/sleep-scroll-check.log：110个Core与5个workspace测试通过；work/sleep-scroll-device.log真机目标BUILD SUCCEEDED；work/sleep-scroll-apple.log双scheme编译结果通过，Widget注册另按日志确认。无针对用户具体视觉症状的可运行UI回归，不能用这些通过替代手机滚动验收。

安装确认：devicectl返回App installed，安装序号2364；无Watch内嵌。Apple脚本后续iPhone Widget注册宿主启动退出3，因此整条脚本未通过，保留现场未重试；不是睡眠页面视觉验证结论。

状态：实现与自动检查完成，UI与真机体验待验收；Gate 3未批准。

## 改变的行为
P-009–P-012：五个底部Tab；今天收拢摘要；睡眠、活动、趋势、我的独立；活动覆盖和各次摘要；共享报告、空/演示状态及报告日说明。P-001–P-008约束沿用。

## 测试证据
- RED：work/tabs-red.log，完整Xcode下新增测试因ActivityBreakdown不存在而编译失败。最初Command Line Tools SDK不匹配已另查，未将该工具失败当成业务RED。
- GREEN：work/tabs-final-check.log，94个Core测试（含5个新增活动投影测试）和5个workspace测试全部通过。
- Apple：work/tabs-final-apple.log，两scheme BUILD SUCCEEDED，Watch四配置及iPhone一配置REGISTRATION PASS；未安装实体手表。
- 真机编译：work/tabs-device-build.log BUILD SUCCEEDED；临时phone-only工程签名，包内无Watch目录。
- 安装：devicectl返回App installed，bundleID com.mirsery.wristlab，数据库序号2332；安装不等于UI和健康数据通过。
- 启动：devicectl返回Launched application with com.mirsery.wristlab bundle identifier；尚未确认用户实际看到的页面或长期运行稳定性。
- git diff --check通过。STDD validate与project-check另运行。

## 切片与TC planned / actual
| 切片/TC | 自动证据 | 未完成 |
| --- | --- | --- |
| S1 / DATA-001、DATA-003部分 | 5个测试：缺失、零、部分覆盖、完整覆盖/结算、单次摘要隔离及稳定编号 | 完整睡眠/活动UI与清除交互 |
| S2 / NAV-001/002、DATA-002/003 | 构建及三个只读评审 | Tab往返、滚动/详情恢复、演示退出、刷新和设置实际交互 |
| S3 / NAV-003 | 平台编译；布局源码使用大字体降列及ViewThatFits | 大字体实际画面、VoiceOver、减少动态效果 |

六个完整TC尚无端到端通过证据，不能标记6/6。新增5个投影测试覆盖两个TC的部分边界，不能证明导航。模拟器simctl安装和--demo启动返回成功，但截图work/tabs-today.png全黑；CUA无法获取Simulator应用，未取得可用渲染/交互证据。

## 评审与检查
code/tests/spec三个只读评审完成，未发现明确阻断，提出两处文案问题已修复并补测。失败模式见failure-modes.md。
stdd ci check-failures退出1：确定性5项通过，4项跳过，TC源码映射0/6；没有用静态字符串标记伪装UI覆盖。structure delta因CLI根路径问题失败，以git diff核对。项目质量配置未启用覆盖率，不额外声称覆盖百分比。

## 剩余验收
手机实际检查五Tab、摘要跳转、详情/滚动恢复、趋势筛选、空/校准/旧数据及大字体读屏。健康数据不导出到测试或截图。待这些体验确认后才可记录Gate 3及归档；本轮不提交或推送。
