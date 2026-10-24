# 开发与真机安装

## 工具链

开发Mac已安装完整Xcode27.1，已通过本机iPhone/Watch/Widget模拟器构建。共享领域包可用Command Line Tools运行：`scripts/swift-test.sh`会在需要时显式发现已安装TestingMacros插件，CI使用GitHub `xcode-27` 镜像中最新的正式版Xcode 27（只支持最新Xcode），不更改测试断言。

```sh
./scripts/check.sh
brew install xcodegen
./scripts/build-apple.sh
```

第二条构建命令需要完整Xcode及iOS/watchOS平台组件。CI还运行`python3 scripts/capture-screenshots.py`并上传实际模拟器截图。

## 真机配置

1. 安装兼容设备系统的Xcode，打开并安装iOS/watchOS组件；在Settings→Accounts添加Apple Account。
2. 若CLI仍指向Command Line Tools，执行`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
3. `xcodegen generate`后打开Wristlab.xcodeproj；为Wristlab、WristlabWatch、WristlabWidget、WristlabPhoneWidget四个target选择可用签名team。
4. 按账号实际可用性配置HealthKit、HealthKit Background Delivery和Watch/Widget App Groups。应用组为`group.com.mirsery.wristlab.watch`（Watch与表盘组件）和`group.com.mirsery.wristlab.phone`（iPhone应用与iPhone小组件，需让Xcode自动注册）；双端真机签名及安装已通过；HealthKit实际授权、App Group数据读取和后台行为仍待验证。
5. 若改bundleID，同步修改project.yml中的Watch companion、Widget前缀，以及WatchBridge/Widget、PhoneWidgetStore/iPhone小组件中的App Group常量和entitlements。保持一致；个人证书/配置不提交。
6. 配对iPhone与Watch，按Xcode引导开启开发者模式，分别运行两个scheme。Widget构建为Watch app内嵌扩展；长按系统表盘→编辑→复杂功能，选择Wristlab的电量/准备度/压力，或在矩形槽位选择状态总览。也可从iPhone系统Watch App编辑。iPhone小组件：长按主屏空白处→编辑→添加小组件，搜索Wristlab选择小或中尺寸；锁屏长按→自定→添加小组件选择圆形、矩形或行内。手机刷新一次后组件才有数据。晨报：设置→晨报通知→打开“推送晨报”并允许通知；次日主睡眠完成后、5:00–14:00内的首次刷新（打开应用或系统后台送达）时收到一条，送达时间不固定。真机验收请分别覆盖“前台打开应用”和“后台送达”两条路径。
7. 手机点“连接Apple健康”后按需授权只读类型；无记录不能当成拒绝授权。已有历史不足14个有效日时显示校准，不造分数。

## 本地演示

两个scheme都支持启动参数`--demo`。普通启动真实模式为空，演示不会写真实快照。演示使用固定日期与合成记录，供截图复现，不作为当下状态。

## 数据路径与调试

手机本地Application Support/Wristlab/health-state.json保存规范记录、配置、anchor和报告，原子写入并使用文件保护。Watch/组件从App Group内watch-receiver.json读取最小快照；iPhone小组件从iPhone App Group内phone-snapshot.json读取手机最近一次真实快照（演示不写入）。不要将这些实际文件上传到issue或仓库。

改数据/模型/时区将全量重建保留窗口；当前实现优先确定性重放，保留最多150日规范记录，不依赖不完整检查点。性能优化不能改变spec输出。

## iCloud界面偏好同步

默认`xcodegen generate`不启用iCloud能力：Info标记为false，签名不申请CloudKit权限；云同步源码保留，普通本地/Watch同步不依赖iCloud。用户已明确要求当前默认关闭，不清除本地数据。

以后需要启用时显式运行`xcodegen generate --spec project-icloud.yml`，选择支持CloudKit的Apple Developer Program团队，再执行以下签名检查。免费Personal Team不支持iCloud能力。仅登录Xcode账户不保证能力可用。不要绕过签名或把默认本地包宣传为云同步可用。再次运行默认生成命令会回到不启用iCloud的配置。

容器为`iCloud.com.mirsery.wristlab`，仅私有库、记录类型`InterfacePreferences`，固定记录`InterfacePreferences-v1`；字段`schemaVersion`、`generation`、`deleted`和白名单JSON `payload`。Debug使用Development，Release使用Production，两环境互不恢复。首次Development创建schema后需通过CloudKit控制台审核并发布到Production，不能由编译推断生产可用。只用四项界面偏好，不填任何健康资料。

Xcode签名构建后，在安装/分发前执行：

```sh
python3 scripts/check-cloud-signing.py /absolute/path/to/Wristlab.app
```

脚本核对真实签名的容器、CloudKit服务和环境是否匹配Info，并验证签名；失败禁止声称云同步可用。脚本通过也不证明服务器容器、schema或当前iCloud账户可用。运行时只使用公开Info标记预检，模拟器明确显示未配置；SDK返回missingEntitlement/badContainer时归为未配置，不使用私有iOS entitlement API。不能保证所有外部分发错误都在首次SDK请求前被发现。

用户在“我的 → iCloud与数据中心”检查账户，明确开启后先读再选择恢复/上传。真实同账户两设备、换账户、离线重试、冲突、删除防复活分别验收；不要在日志打印账户标识或CloudKit记录内容。

本change当前签名仍受Personal Team限制，手机保留此前趋势页版本。配置日志见`work/cloud-phone-build.log`（未登录）与`work/cloud-phone-signed.log`（登录后团队能力不足）；不提交个人签名资料。

## 真机验收流程

Watch独立版本需重新签名以包含Watch target的只读HealthKit能力和使用说明；默认不启用iCloud。升级仍保留手机同步模式，手表“更多 → 手表独立设置与连接”确认独立时区/睡眠目标/可选最大心率/训练模式后主动连接健康。断开手机再前台刷新，分别记录实际可读类型和历史覆盖（不要导出真实样本）；历史不足可能长期只显示校准进度，不降低14有效日门槛。重连不自动切源，手动切回手机模式可继续请求手机快照。检查App与表盘来源、重启缓存、两分区清除及锁屏失败，不能用签名构建代替此验收。

`Apps/SharedHealth`为双端共享分页适配，iOS心情逻辑保留在`HealthKitMoods.swift`。每页上限500，Watch单次读取最多接纳200000个规范记录与删除ID组合，超限整批失败不推进anchor；该保护不代表已验证耗电/内存预算。首版不为Watch开启HealthKit后台观察或专用常驻会话。

依照[验证记录](validation.md)和[006](../specs/006-acceptance.md)逐项记录；模拟器编译与合成截图不证明HealthKit真数据、锁屏后台执行、签名、Watch送达或组件刷新可用。

参考：[HealthKit授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

## Widget运行注册回归

`build-apple.sh`现在还调用`python3 scripts/test-widget-registration.py`与`--platform ios`，要求可用的watchOS与iOS（iPhone）模拟器运行时。测试在隔离宿主的App初始化阶段（不依赖界面激活）执行四个Watch与一个iPhone生产Widget配置，不读取健康缓存；注册时的文本前置条件只能在运行时发现。可用`--device <模拟器UDID>`指定设备，日志保存在忽略提交的work/widget-registration-test与work/widget-registration-test-ios目录。失败时脚本会打印本次启动后写出的崩溃报告和模拟器日志（最近200行），并保存为同目录的diagnostics.log；不重试，偶发失败也保留现场。
