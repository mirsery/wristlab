# 切片

依赖图只有watch-sync，无环。S1纯协议与状态→S2平台集成，顺序执行。接口变更与双端旧版本兼容风险高；不并行修改文件。S1四个新增测试先验证缺失API失败；S2补适配器集成测试，再检查真实平台编译与设备验收。

工具限制：experience缺requests；structure delta短名不接受，使用完整change名重试。项目无.stdd/rules/common目录，遵循AGENTS与Swift规范；没有配置SwiftLint则不新增。
