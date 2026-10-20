# Wristlab

自用、开源的 iPhone + Apple Watch 健康仪表盘实验项目。参考 PeakWatch 的产品方向，使用原创界面和公开说明的实验性评分模型。与 PeakWatch 无关联。

## 当前状态

这是项目骨架：包含 iOS/watchOS SwiftUI 演示页、共享 Swift Package、只读 HealthKit HRV 读取入口、spec 与 CI。演示数据始终标记为“演示数据”。**压力、恢复、身体电量算法、手机手表同步和表盘组件尚未实现。** 不用于医疗判断。

## 开始

```sh
# 在具备完整 Swift Testing 支持的 Swift / Xcode 环境中运行测试
./scripts/check.sh
# 安装完整 Xcode 和 XcodeGen 后生成并编译项目
brew install xcodegen
xcodegen generate
./scripts/build-apple.sh
open Wristlab.xcodeproj
```

项目默认 iOS 17 / watchOS 10 / Swift 6。生成的 Xcode 项目不提交，以 `project.yml` 为源文件。CI 使用 macOS 15 上的 Xcode 16.4。

本机当前 Command Line Tools 的测试插件不可用，完整测试由 CI 执行。真机安装还需 Xcode、配对的 iPhone/Watch、相应开发者模式和可用签名配置。当前没有验证真机安装；参见 [开发指南](docs/development.md)。

## 文档

- [代理规则](AGENTS.md)
- [Spec 目录与交付状态](specs/README.md)
- [架构](docs/architecture.md)
- [协作和 CI 规则](CONTRIBUTING.md)
- [隐私边界](PRIVACY.md)

MIT License。请勿上传真实健康数据或签名材料。
