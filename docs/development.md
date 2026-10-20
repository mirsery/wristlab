# 开发与真机安装

## 当前环境

初始化时只有 macOS Command Line Tools 与 Swift 6.4，没有完整 Xcode，也没有已配置的付费开发者账号。共享模型可独立编译；初始化时本机 `swift test` 因当前 Command Line Tools 缺少可用的 Swift Testing 插件而失败（默认构建模式找不到 TestingMacros，native 模式找不到 Testing）。完整测试和 Apple targets 编译使用 CI 的完整 Xcode 环境。未验证真机安装。

## Xcode 就绪后

1. 从 Mac App Store 安装兼容设备系统版本的 Xcode，打开一次并安装 iOS/watchOS 平台组件。
2. 在 Xcode Settings → Accounts 添加 Apple Account；真机签名权限与能力以账号实际配置为准。
3. 若命令行仍指向 Command Line Tools，执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
4. 安装 XcodeGen，执行 `xcodegen generate`，再执行 `./scripts/build-apple.sh`。
5. 打开工程，为两个 app target 选择自己的 signing team；需要时修改 `project.yml` 的 bundle identifier，并同步 Watch companion identifier。团队设置保存在本地，避免提交个人签名配置。
6. 配对 iPhone 与 Watch，按 Xcode 引导启用需要的开发者模式；先选择 iPhone 运行 Wristlab，再选择配对 Watch 运行 WristlabWatch。
7. 在手机点击授权按钮，读取最近 7 天最新 HRV。无数据时检查是否佩戴手表产生记录及健康权限；不要把空结果当成拒绝授权的确证。

## 验证清单

- 手机、手表均能启动，演示标签清晰；数值只代表合成数据。
- 手机授权取消、无样本和正常返回均不崩溃。
- 真机读取显示单位 SDNN ms、采样时间；不会自动把它转成压力值。
- 当前手表没有真实同步和 complication；不要据此宣称完整 MVP 已交付。

## 常用命令

```sh
./scripts/check.sh
./scripts/build-apple.sh
```

参考：[HealthKit 授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。
