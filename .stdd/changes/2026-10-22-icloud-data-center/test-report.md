# iCloud与数据中心 — Build验证报告

状态：Gate1/2已获用户确认，Core/适配器/界面已实现；**含云手机签名、安装、真实CloudKit和两设备换机验证未完成**。Gate3未批准，未提交，未安装实体Watch。

## 行为与规格
P-024/P-025、CLOUD-001–006：我的增加当前系统iCloud账户状态、独立同步状态/最近确认/待传/退避时间、恢复与冲突选择、关闭及本机/云端清除。默认关闭，首次先读再选择；演示不上传。
独立InterfacePreferences仅四个界面选择，独立受保护缓存/outbox；健康、体重、目标、计划、配置和整库均不进入支路。账户与Development/Production隔离，request/context及Core epoch阻旧响应。服务器changeTag检查、删除标记、服务端retry-after、未知schema拒绝和失败保留本机均有实现。
隐私、README、架构与开发指南同步更新；无独立登录或自建后端。账户切换只隔离云偏好，不把应用变为Apple ID多用户健康库。

## 验证证据
- RED：work/cloud-red.log缺类型；评审后补充测试的RED见work/cloud-review-red.log。
- 已执行阶段记录：work/cloud-core-check.log及work/cloud-check.log为148 Core＋5 workspace；work/cloud-review-check.log为154＋5；work/cloud-race-check.log为159＋5。后续新增测试以work/cloud-release-check.log最终结果为准。
- work/cloud-final-check.log最终一次因README先链接未创建的本报告而在文档门禁失败，创建报告后另跑release日志，不掩盖该失败，不拿它当产品RED。
- work/cloud-final-apple.log：iOS/watchOS两项BUILD SUCCEEDED、Watch/phone两项REGISTRATION PASS。
- work/cloud-final-device-compile.log：真实iOS分支generic设备编译BUILD SUCCEEDED（CODE_SIGNING_ALLOWED=NO），不是签名或可安装包。
- scripts/check-cloud-signing.py语法检查通过；work/cloud-signing-negative.log在未签名包上正确拒绝，不能替代真实签名包阳性验证。
- git diff --check与STDD结构/validate检查另运行；ci check-failures的源码映射/跳过项如实记录，不用手写coverage掩盖。

## 测试映射与边界
CloudPreferencesTests现24个函数，全为合成账户和偏好。不是CloudKit实际服务或UI测试。清本机操作清除各账户偏好缓存及待传队列并重置确认时间，不仅清当前账户，另有跨账户回归。

| 场景 | 主要模型证据 | 仍未验证 |
| --- | --- | --- |
| CLOUD-001 账户 | unavailableAccountNeverEnables；fake账户切换 | 真机未登录/受限/通知、真实签名/容器 |
| CLOUD-002 白名单 | payload四键、完整envelope键集合、Trend导航映射；CK适配器拒绝额外用户字段 | 实际CKRecord服务器写入、演示UI禁写 |
| CLOUD-003 恢复冲突 | 首次读后选择、远端修改需确认、未知schema、恢复等待中本地编辑转conflict | 首次安装与冲突选择的真实UI/云版本 |
| CLOUD-004 隔离 | fetch/save暂停后切B/关闭、旧epoch编辑、cancel；旧回调不改新本地 | 真实账户通知与已提交云写后切账号的服务端结果 |
| CLOUD-005 离线持久化 | 离线队列重开、retry-after及重开、保存中编辑保留pending、服务端成功本地失败、损坏文件保留 | 真实配额/网络/锁屏文件保护、重启UI接线 |
| CLOUD-006 删除 | 正常删除阻旧副本、CAS时删除暂停、删除失败落盘重开后显式重试 | 两设备删除传播与实际不复活 |

保存已发起后关闭并不保证撤销已到服务器的请求；测试只断言旧回调不会重新启用或覆盖新账户的本地状态。失败文案已改“结果尚未完整确认”，不再声称服务器一定没变。

## 三路评审处理
代码评审发现CAS冲突重读删除标记仍可直接上传，已修为暂停并需重新开启，回归通过。规格评审要求retry-after和签名门禁，已补持久退避、SDK错误分类及签名脚本；无私有API，公开Info预检不能保证所有错误均首次SDK前发现，此限制已明确。测试评审要求可控晚回调/持久失败与新编辑竞态，已补；最终三路复核无剩余确定代码阻断。
UI增加可立即停止正在等待的同步；本地保存失败也发布已确认偏好，避免界面误认已保存。其实际点击/滚动、辅助字体和账户通知调度仍需独立验收。

## 真机签名阻塞
work/cloud-phone-build.log：未识别Xcode账户且旧描述文件无iCloud。用户回复“已经登陆”后，work/cloud-phone-signed.log明确当前Personal Team不支持iCloud capability，不能生成所需profile。没有绕过签名、没有安装无能力替代版，手机仍是此前趋势页2388版本。
已询问是否有支持CloudKit的开发者团队；没有团队信息时不猜team，不接触密码或改未知账户。后续须用支持团队构建、签名门禁通过，再实际私有库读写、Production schema与同账户两设备恢复。单设备启动也不能证明换机同步。

用户随后回复“暂时没有，先保留实现”。遵照此决定不再尝试签名/安装，手机现有版本不覆盖。后续团队能力具备时恢复真机验证，当前不声称云可用或Gate3完成。

## 最终门禁补充
work/cloud-release-check.log：164个Core＋5个workspace通过，共169项；新增“清本机也清其他账户缓存”后，以work/cloud-release-final-check.log最终结果为准。签名门禁脚本语法和unsigned拒绝已实际执行；真实签名包阳性路径尚未执行。
work/cloud-stdd-check.log：ci check-failures因Swift源码扫描映射0/6失败，另5项跳过；人工函数映射不替代该检查。git diff --check、STDD validate和project-check通过，不能宣称所有流程门禁全绿。
work/cloud-release-apple.log保留最终模拟器构建/组件注册结果；这一轮只本地验证，不做含云真机安装。

最终结果：work/cloud-release-final-check.log为165个Core＋5个workspace测试全部通过，共170项；work/cloud-release-apple.log两scheme BUILD SUCCEEDED及Watch/phone两项REGISTRATION PASS。文档链接、git diff --check、STDD validate/project-check通过。含云真机包仍未签名/安装，真实云和两设备仍未验，不代批Gate3。
