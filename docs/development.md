# 开发与真机安装

## 工具链

开发Mac当前未安装完整Xcode。共享领域包可用Command Line Tools运行：`scripts/swift-test.sh`会在需要时显式发现已安装TestingMacros插件，CI使用完整Xcode16.4，不更改测试断言。

```sh
./scripts/check.sh
brew install xcodegen
./scripts/build-apple.sh
```

第二条构建命令需要完整Xcode及iOS/watchOS平台组件。CI还运行`python3 scripts/capture-screenshots.py`并上传实际模拟器截图。

## 真机配置

1. 安装兼容设备系统的Xcode，打开并安装iOS/watchOS组件；在Settings→Accounts添加Apple Account。
2. 若CLI仍指向Command Line Tools，执行`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
3. `xcodegen generate`后打开Wristlab.xcodeproj；为Wristlab、WristlabWatch、WristlabWidget三个target选择可用签名team。
4. 按账号实际可用性配置HealthKit、HealthKit Background Delivery和Watch/Widget App Groups。应用组为`group.com.mirsery.wristlab.watch`；真机签名和capability尚未验证。
5. 若改bundleID，同步修改project.yml中的Watch companion、Widget前缀，以及WatchBridge/Widget中的App Group常量和两个entitlements。保留三者一致；个人证书/配置不提交。
6. 配对iPhone与Watch，按Xcode引导开启开发者模式，分别运行两个scheme。Widget构建为Watch app内嵌扩展，再在表盘添加Wristlab组件。
7. 手机点“连接Apple健康”后按需授权只读类型；无记录不能当成拒绝授权。已有历史不足14个有效日时显示校准，不造分数。

## 本地演示

两个scheme都支持启动参数`--demo`。普通启动真实模式为空，演示不会写真实快照。演示使用固定日期与合成记录，供截图复现，不作为当下状态。

## 数据路径与调试

手机本地Application Support/Wristlab/health-state.json保存规范记录、配置、anchor和报告，原子写入并使用文件保护。Watch/组件从App Group内watch-receiver.json读取最小快照。不要将这些实际文件上传到issue或仓库。

改数据/模型/时区将全量重建保留窗口；当前实现优先确定性重放，保留最多150日规范记录，不依赖不完整检查点。性能优化不能改变spec输出。

## 真机验收

依照[验证记录](validation.md)和[006](../specs/006-acceptance.md)逐项记录；模拟器编译与合成截图不证明HealthKit真数据、锁屏后台执行、签名、Watch送达或组件刷新可用。

参考：[HealthKit授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。
