# 手机连接修复阶段报告

2026-10-24；Gate1/2/3由用户真实确认，最终回复“确认，本轮修复验收并本地归档”。Watch开发连接1035曾阻塞、后已恢复并独立核对安装；本报告不把手机更新当Watch安装成功，也不把合成测试当真实健康可读。Gate3只确认本轮两项故障修复，未验项目继续保留。

## 行为变化与规格

PHC001至006：连接首await前提示系统请求/读取及忙碌状态、防重复授权；模型持有共享任务，不随页面取消，显式停止仍取消。并发连接强制读与旧运动重读保留，观察最多一次后续刷新，失败无无限重试。坏缓存明确提示并原路径重试、不覆盖失败文件；失败保留报告/anchor/手动计划，空结果不推断拒绝授权。生产默认缓存路径、HealthKit只读五类、评分、schema、通知及iCloud关闭边界不变。新增通知清理注入仅隔离测试宿主身份，生产默认原动作。

## 实际证据

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 原生产模型诊断RED | 授权等待无状态/busy反馈，取消调用者使刷新取消；两个模式退出1 | work/phone-health-probe/red.log、cancellation-red.log |
| 正式RED | 原生产控制流在授权、取消、并发、缓存恢复、清除取消处失败；计划夹具不共享actor的错误另行修正，不当生产缺陷 | work/phone-health-probe/formal-red-complete.log |
| 旧运动重读RED | 并发时重读丢失，2断言失败，随后保留重读请求修复 | work/phone-health-probe/rebuild-red.log |
| 新合成回归 | 14函数全部通过，包含真正忽略取消的非空晚batch，磁盘records/anchor/report及停止文案不复活 | work/phone-health-probe/green-review-fixed.log |
| 最终全量检查 | 196 Core+35 workspace+14手机=245项通过 | work/phone-health-check-final.log |
| 最终Apple检查 | iOS/Watch双构建成功、3日期契约、5Watch/1iPhone组件生产注册通过 | work/phone-health-apple-final.log |
| 2403设备签名包 | generic iOS内嵌Watch/两组件构建成功，四包版本/签名/App Group/HealthKit/无云检查通过 | work/phone-health-device-build.log、phone-health-device-signing.log |
| PHC007手机2403 | 同包覆盖sequence2188、版本/启动确认，但用户明确设置入口仍无反馈，不计通过，已触发S2补漏 | work/phone-health-phone2403-install.log、phone-health-phone2403-verify.log、phone-health-phone2403-launch.log及用户设置入口反馈 |
| S2设置UI RED/GREEN | 原生产SettingsView实际点击后无就近状态且按钮仍enabled，修后4个XCTest UI全部通过 | work/settings-connection-ui-red.log、settings-connection-ui-green.log |
| S2最终完整检查 | 245项Swift回归通过、iOS/Watch双构建、3日期契约/5Watch和1iPhone注册、4项设置UI通过 | work/settings-connection-check-final.log、settings-connection-apple-final.log |
| 2404签名与手机安装/反馈 | 四包签名/版本/组/HealthKit/无云验证通过；手机覆盖sequence2204，实际查询0.1.0（2404）并普通启动成功；用户从真实设置入口点击后回复“已更新本地报告” | work/settings-connection-device-build.log、settings-connection-device-signing.log、settings-connection-phone2404-install.log、settings-connection-phone2404-verify.log、settings-connection-phone2404-launch.log及当前对话 |
| Watch最新状态 | 配对恢复后查旧2401，再实际覆盖2402（sequence1000）、核对0.1.0（2402）、普通启动及延迟主进程存在；用户回复“不再闪退，页面可打开”，不扩大成表盘/后台/活动值完整验收 | work/calendar-crash-watch-current-version.log、calendar-crash-watch-restored-install.log、calendar-crash-watch2402-restored-verify.log、calendar-crash-watch2402-restored-launch.log、calendar-crash-watch2402-restored-processes.log及当前对话 |

三路代码/测试/规格只读评审已返回，代码无新增阻断；按测试评审修复“ignoreCancellation仍检查取消”的假覆盖并由代码/测试复核确认。测试进入等待有5秒限制、测试进程300秒限制；若干并发任务仍固定Task.yield次数，未穷举调度。晨报等待后的代次guard已补，但未单独注入真实通知挂起；真实系统授权长等待、健康样本、后台/性能/手表表盘交互均未由本次合成测试验证。

S2三路评审/脚本复核通过：测试尊重既有Xcode选择，只在CLT时回退，筛iOS17以上且SDK兼容模拟器，只清理自己的settingsprobe/runner。宿主直接嵌入实际SettingsView和模型、合成HealthKit/桥接及表盘导航替身；4项是真实设置视图滚动点击测试，不含生产首页到sheet完整导航或真实HealthKit授权。保留原设置输入/弹层与底部状态，在连接同组补状态、按钮标签和ProgressView、busy/demo禁用，不改变读取语义或权限。245个Swift函数与4个XCTest UI分开计数，不混称249项Swift Testing。

## 流程与隐私

validate、project-check及diff检查通过；既有integrated-weekly-review的AND11警告未改。CLI ci仍Python-only扫描误报0/7，canonical旧路径与无coverage配置跳过，experience缺requests/structure默认路径错误均留日志、不改上游。没有配置行/分支coverage、formatter或UI E2E，不伪造比例。失败模式逐项见failure-modes.md，本地经验EXP013；无社区/全局记忆上传。

未卸载/清除真实数据、导出健康样本、添加写权限、开启iCloud或提交推送。权限请求完成、空样本、计算结果、安装与设备验收分别表述。最终手机2404实际设置入口已获“已更新本地报告”的用户反馈，覆盖PHC007本轮连接/更新闭环；不据此断言所有健康类型/评分/表盘/后台性能正确。最终报告披露边界后，用户已实际确认Gate3及本地归档。
