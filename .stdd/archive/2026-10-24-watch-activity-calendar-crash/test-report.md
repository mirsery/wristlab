# 活动摘要calendar闪退：阶段报告

2026-10-24；Gate1/2/3均由用户实际确认；Gate3回复“确认，本轮修复验收并本地归档”，只验收本轮两个故障修复并保留其他平台缺口。2401真机发现不能被先前代码/模拟器Gate3覆盖为通过。本次仅改Watch日期构造；手机“无数据/刷新已取消/连接无反应”另属独立PHC变更，未在本change擅自改手机业务逻辑。

## 验证结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 真机原始问题 | 用户确认闪退，过滤控制台同NSInvalidArgumentException：Date components require a calendar | work/watch-care-watch-crash-summary.log |
| 原行为平台RED | 真实HKQuery谓词相同异常/SIGABRT，272ms退出 | work/calendar-crash-platform-red.log |
| 修复平台GREEN | 生产helper参数进入真实HKQuery，3个新增函数/3标记通过，纯合成日期、不授权不读数据 | work/calendar-crash-platform-green.log |
| 全量回归 | scripts/check.sh退出0，196 Core+35 workspace=231通过 | work/calendar-crash-check.log |
| Apple完整检查 | iOS/Watch BUILD SUCCEEDED，3日期契约、5Watch/1iPhone组件生产注册通过 | work/calendar-crash-apple.log |
| 2402签名构建 | 含内嵌Watch/两组件，四包2402签名/组/HealthKit/无云验证通过 | work/calendar-crash-device-build.log、calendar-crash-device-signing.log |
| 2402手机安装 | 同包覆盖成功sequence2180，实际查询0.1.0（2402），普通启动成功，后续主进程仍存在；不等于健康读取恢复 | work/calendar-crash-phone2402-install.log、calendar-crash-phone2402-verify.log、calendar-crash-phone2402-launch.log、calendar-crash-phone2402-processes.log |
| 2402手表安装与启动 | 开发连接恢复后实际查旧2401，再覆盖2402成功sequence1000，核对0.1.0（2402）、普通启动及延迟主进程存在；此前1001/1035为历史失败 | work/calendar-crash-watch-current-version.log、calendar-crash-watch-restored-install.log、calendar-crash-watch2402-restored-verify.log、calendar-crash-watch2402-restored-launch.log、calendar-crash-watch2402-restored-processes.log |
| 真机用户反馈 | 用户明确“不再闪退，页面可打开”；本轮启动/切页崩溃修复获实际反馈，不宣称所有活动值/表盘/后台已验 | 当前对话用户状态反馈，无健康数值 |
| 手机诊断 | 用户确认按钮正常可点击但无变化；主进程存在、该App崩溃文件列表0；三次调试器诊断未取得busy/status，已结束本次调试器并普通重启App；未读健康内容 | work/phone-cancel-processes.log、phone-cancel-crash-files.log、phone-cancel-target-flags.log、phone-cancel-debug-cleanup-launch.log |
| 结构/链接/Diff | validate与git diff --check通过；CI Python-only仍0/3，不当Swift失败或全流程通过 | work/calendar-crash-ci.log |

## TC与切片

- TC-ACAL-001：checkActivityCalendar_TC_ACAL_001，生产参数→真实平台谓词，无calendar原行为RED，补calendar/timeZone GREEN。
- TC-ACAL-002：checkActivityDayBoundaries_TC_ACAL_002，UTC/上海/纽约、近午夜/23与25小时DST，字段与同clock一致。
- TC-ACAL-003：checkRepeatedActivityPredicate_TC_ACAL_003仅重复构造CONTRACT，不冒充设备测试；后续真实2402同包安装、版本/启动/延迟主进程与用户“不再闪退，页面可打开”另有证据。用户未提供各类活动值或专门的长时后台结果，不能扩大验收。

S1新增3个Apple宿主测试函数；原Swift测试仍231，不把3个宿主函数混称234项Swift Testing。后续手机change全量245项及4设置UI通过，未据此增加本change测试数。无行/分支coverage配置，不伪造覆盖百分比。设备连接现已恢复，本轮启动/切页获得用户反馈；最终Gate3报告已实际确认，并按保留缺口范围本地归档。

## 审查、经验与偏差

代码/测试/规格3路只读审查无确定阻断，一致要求保留ACAL003完整设备缺口。补calendar/timeZone与批准方案一致；没有改变系统日、评分、权限或云。上游CLI experience缺requests、structure错误根目录仍记录，不改上游。新本地EXP-20261024-012记录“演示跳过适配器会漏ObjC契约异常”，不上传社区或全局记忆。

## 历史阻塞与保留边界

用户确认重启手表后仍失败：安装work/calendar-crash-watch-postreboot-install.log报1035；Xcode设备列表work/calendar-crash-postreboot-xcdevice.json仅手机available=true、手表available=false且正在局域网浏览，详情查询超时。用户继续反馈“手表不行”，未实际核对到2402。手机问题另获Gate1，进入独立变更2026-10-24-phone-health-connection，不改变本change审批范围。

以上断连记录为历史。本次最终状态：Watch2402实际安装、版本与启动/延迟主进程已核对，用户回复“不再闪退，页面可打开”。手机后续另change修到2404，用户回复“已更新本地报告”，并非本calendar变更擅自扩围。未执行unpair、卸载清数据、导出健康数据或开启iCloud。最终报告披露范围与未验项后，用户已确认Gate3并授权本地归档；表盘/后台/性能及活动值逐项正确性不在本次验收中冒充通过。
