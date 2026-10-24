# 手机连接修复：BUILD阶段

Gate1用户实际确认“确认，按这个范围修复”；Gate2用户实际确认“确认，按此方案实施”：连接/读取任务与状态提示、补测试、同包安装，不清数据、不增权限、不改评分或iCloud。生产最小修复及14个合成回归已完成；Gate3未批准。

现状：手机2402已安装、核对版本、普通启动与后续主进程存在；用户仍确认按钮可点击无反应。Watch重启后安装仍RemotePairing1035，xcdevice显示available=false、正在局域网浏览，手机available=true；不再重复要求解锁或宣称手表已更新。

诊断闭环：work/phone-health-probe/run.py直接编译生产DashboardModel完整文件，只把缓存路径定向临时目录并用合成适配器链接；原生产文件未改。授权挂起时visible_feedback=false及duplicate_blocked=false，RED退出1；cancellation模式已取消调用者传入刷新，caller_cancel_did_not_abort_read=false，RED退出1。仅证明生产控制流缺陷，不证明真机系统请求/权限的具体原因，不读取真健康值。

实现：阶段反馈/占用在await前建立，模型持有单任务，连接强制读取及旧运动重读不丢、普通事件合并有界，页面取消不误杀而显式停止继续生效；缓存重试不破坏原文件。14函数覆盖PHC001至006，PHC007真实手机单列。初始化仅注入原路径、HealthKit适配器及通知清理，生产默认不变；无App身份SwiftPM宿主通知异常已隔离，合成计划夹具改由同一模型提交，未据错误夹具改生产仓库。

三路只读评审无新增代码阻断；发现PHC005假覆盖后，替身真实忽略取消、返回非空batch并验证磁盘records/anchors/report及停止文案不复活，复核通过。晨报await后补代次guard，若干Task.yield竞争调度仍是残余，非穷举证明。work/phone-health-probe/green-review-fixed.log完整14通过。

最终scripts/check.sh为196 Core+35 workspace+14手机=245项通过；scripts/build-apple.sh双端BUILD SUCCEEDED，原3日期契约/5Watch及1iPhone组件注册通过。2403完整设备签名构建与四包版本/签名/App Group/HealthKit/默认无云校验通过，设备安装正在单独执行。签名沙箱CSSMERR_TP_NOT_TRUSTED经正常权限只读核验通过，不改证书或信任设置。CLI experience缺requests、ci Python-only误报0/7与canonical旧路径限制均保留原日志，不改上游。新经验EXP013只保存在项目本地。

最新设备结果：手机2403已同包覆盖sequence2188，实际查询0.1.0（2403），普通启动成功；已询问用户连接后的阶段/最终状态，不需健康数值。不能仅据启动回执称健康读取恢复，PHC007完整待验、Gate3未批准；Watch新版仍无法核对。未卸载、清真实数据、开启iCloud、推送或提交。

用户后续明确“首页的设置页面中点击连接 Apple 健康无反应”，2403未完成设备验收。设置页状态原在长表单底部、首页进度被sheet遮住；S2属于原批准的连接可见反馈补漏，不重新伪造Gate。已补生产SettingsView连接按钮标签/进度、就近状态和busy/demo禁用，保留原底部状态、输入及弹层。隔离iOS宿主直接嵌入真实设置视图和真实模型、合成适配器，原设置点击RED（缺状态/按钮仍enabled/标签不变），修后4项XCTestUI GREEN（work/settings-connection-ui-red.log、settings-connection-ui-green.log）。不是完整首页sheet导航或真实健康E2E。

三路S2只读审查无生产范围阻断，按测试评审修复脚本硬编码Xcode与未筛SDK runtime问题。最终完整check/build及手机2404签名在执行。Watch用户说配对上后再试仍1035（work/calendar-crash-watch-repaired-install.log）；用户又答“可以了”，正只读核对实际版本，不把配对口头反馈当安装证据。Gate3继续未批准。

最新结果（04:20后）：S2最终check245项通过，Apple双构建/原平台探针/4设置UI全部通过；2404四包构建和实际验签/默认无云通过，手机覆盖sequence2204，实际版本0.1.0（2404）、普通启动成功。已请用户按实际首页→设置→连接与演示入口回报按钮下文字，不请求健康数值，PHC007/Gate3仍待验收。

Watch开发连接真正恢复后查到旧2401；实际覆盖2402成功sequence1000，查询0.1.0（2402）、普通启动成功，稍后仍有主进程（非仅Widget）。已请用户切页及活动刷新反馈是否闪退，不把这几个元数据回执当完整真实活动验收。原Watch修复change同步更新，未卸载或清数据。

最终用户真实反馈已收到：手机2404在实际首页→设置→连接与演示操作后回复“已更新本地报告”；Watch2402回复“不再闪退，页面可打开”。本轮连接更新/页面不崩溃闭环已有设备+用户证据，不推断所有健康类型/评分/活动值/表盘/后台正确。已向用户展示最终结果及未验项后等待Gate3报告确认；不要将前述状态回复伪作尚未询问的最终报告批准。

交付最终状态：用户对最终Gate3报告明确回复“确认，本轮修复验收并本地归档”，CLI已记录；本change本地归档、Canonical及Human View合并，Deliver completed。历史进度中的Gate3待确认现已由真实确认结束，但各健康类型/评分、活动值、表盘、后台与性能仍不追认全验。应用代码在交付阶段未修改，无提交/tag/push、经验上传/知识图谱合并或额外真机动作。
