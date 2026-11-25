# 活动页整合 — Build验证报告

Gate1/2已获用户确认；实现完成，Gate3与真实交互验收待确认。未将本轮或其他活跃change归档，未提交。

## 行为变化
P-020/P-021：活动页依次为今日安排/模式/健康进度/人工操作、本周摘要、负荷摘要及详情入口。自动大卡不再占据首页；管理计划页以自动/手动菜单组织原有生成采纳、周反馈、切回手动、模板编辑和重读操作；负荷区间和运动列表进入二级详情。
空计划主入口“建立计划”，已有或未来计划为“管理计划”；实际模式按分析日判断，未来自动计划独立说明生效日期。保存手动模板提示切回手动；查看分段/取消不执行写入。周摘要默认两列、辅助字体一列；来源切换重建活动导航并防御清理内联编辑状态。
不改评分、计划公式、数据schema、HealthKit权限或Watch协议；睡眠修复、仅kg与其他未提交改动保留。

## 模型及编译证据
- RED：work/activity-ui-red.log，新ActivityPlanPresentation类型不存在；后续发现可抛错短路表达式编译问题已改为guard后return try。首次全量检查因TC表格格式未被CLI识别而失败，规范格式后通过，不将格式失败称为产品RED。
- work/activity-ui-final-check.log：136个Core＋5个workspace测试，共141项通过。新增7函数，覆盖空态、手动+未来自动、仅未来自动、取消未来、暂停休息快照、当前自动已完成、25小时分析日周摘要；只读构建不改变PlanningState。
- work/activity-ui-apple.log：iOS和watchOS模拟器BUILD SUCCEEDED；Watch注册通过，phone注册宿主启动失败（simctl code3），保留原日志。work/activity-ui-final-apple.log最终复跑两scheme BUILD SUCCEEDED、Watch与phone两项REGISTRATION PASS，不删除先前失败证据。
- work/activity-ui-phone-build.log：phone-only真机目标BUILD SUCCEEDED，包内无Watch目录。安装及启动结果单列，不能从编译推断。
- git diff --check、STDD结构/validate通过。work/activity-ui-stdd-check.log：ci check-failures仍因Swift源码扫描映射0/4失败并有跳过项，不声称全部STDD门禁全绿。项目脚本未引入新的测试工具或覆盖率伪数据。

## TC映射与未验范围
| TC | 证据 | 未验范围 |
| --- | --- | --- |
| ACTUI-001 | 7函数中的日期模式、空态、未来及当前自动，源码顺序复核 | 界面唯一主入口、实际首屏顺序与真机可见性 |
| ACTUI-002 | canceledFuture投影及只读state相等；管理Picker仅本地state，原保存路径复用 | 浏览/取消前后revision的交互记录、管理所有操作完整点击链 |
| ACTUI-003 | 休息/完成快照投影；已有共享仓库健康新增删除与人工状态参数化测试回归 | 健康与人工在UI并列、修订与长文本实际展示 |
| ACTUI-004 | DST周边界模型测试；Apple编译及静态核对覆盖度/编号语义/单列辅助字体 | 窄屏、最大辅助字体、详情导航、Tab往返、刷新滚动、演示切换及手机安全区 |

## 三路只读评审
代码与规格评审未发现确定新增阻断。测试评审最初怀疑内联编辑跨演示来源保留，复核父级activity栈id包含demoEnabled后撤回该finding；本轮另加显式关闭清空编辑作为防御，不能写成修复已证实漏洞。报告原本nil的清除边界仍需交互测试。

## UI证据限制
CUA选择Simulator返回Invalid app，无法实际操作；未用源码或编译冒充UI通过。手机点击/滚动与真实HealthKit匹配仍需用户验收。实体Watch不安装。手机安装成功也不等于Gate3通过。

## 手机安装与启动
work/activity-ui-install.log确认iPhone mi安装成功，bundle com.mirsery.wristlab，databaseSequenceNumber 2380，包内无Watch。work/activity-ui-launch.log启动失败，明确为Locked；需要用户解锁后自行打开或继续启动，不称本轮启动成功。未重复要求安装手表。

用户随后回复“解锁了”。work/activity-ui-unlocked-launch.log确认Launched application with com.mirsery.wristlab bundle identifier，新版启动成功；实际页面点击、滚动和Gate3仍待用户验收。
