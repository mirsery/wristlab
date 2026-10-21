# iPhone小组件：Build 测试报告

2026-10-22；分支feat/phone-widgets（叠在feat/mood-records上）。Xcode 27.1，iPhone 18 Pro与watchOS 27模拟器。Gate 1/2已确认（本批授权），Gate 3待用户真机验收。

## 结果

- `./scripts/check.sh`：86 Core + 5 workspace通过；`./scripts/build-apple.sh`：双端构建与watchOS、iOS两个注册运行检查通过；`git diff --check`通过。Core RED为缺接口编译失败（work/phonew-red.log）。
- iOS注册运行检查：生产配置输出`REGISTRATION: phone OK`与PASS；以插值名称的临时源码执行时退出1并打印`Fatal error: Formatted text for configurationDisplayName is not supported`（work/phonew-probe-red.log，临时源码不提交）。

| TC | 结果 | 证据 |
| --- | --- | --- |
| PHONEW-001 | 通过 | 真实/演示/损坏/32768与32769字节/未知schema与正对照/无效与有效清除标记 |
| PHONEW-002 | 通过 | 与ComplicationPresentation一致、真实0、部分、单项过期、缺失、显式时间线[0,901,3601,36001]与+1000后、无快照提示刷新、清除 |
| PHONEW-003 | 通过 | build-apple.sh中的iOS注册运行检查；RED复现 |
| PHONEW-004 | 未验证 | 静态检查（深色配色、圆形原因、部分标注、privacySensitive、时区）；系统渲染、添加与刷新待真机 |

## 复审（C1）

代码与测试/文档复审完成，blocker（浅色模式原因不可见）与其余发现已处置（ADJ-001～004）。

## 缺口

- 小组件实际外观、锁屏遮盖、系统刷新时机与新App Group签名均待真机。
- CI apple作业超时由25分钟提高到60分钟；截图步骤尽力而为（不阻断、单独12分钟上限）。#10的CI曾因iOS探针10分钟、截图22分钟而超过40分钟被取消。PR #10首次CI中iOS探针构建超过脚本240秒上限（冷启动编译），已把探针构建上限提高到600秒。第二次CI中iPhone探针进程已启动但界面场景未激活，`.task`从未执行而超时；探针改为在App.init中执行配置（watchOS与iOS相同），本地两平台PASS且两平台插值名称RED均复现fatal。以PR检查为准。
- 合并后main的CI（de1d549）中watchOS探针启动45秒无输出、无崩溃报告而超时；同一代码在#10最后一次CI通过。探针启动等待放宽到180秒（不重试，真实trap仍会打印Fatal error）。
- 根因更正：本轮ADJ-004把模拟器选择改为“最新运行时”，CI在Xcode 16.4下改选watchOS/iOS 26的Series 11与iPhone 17 Pro（此前为与SDK匹配的Series 10），随后出现探针启动挂起与exit 3。改为选不高于当前SDK版本的最新运行时，并在启动失败时打印simctl输出。
