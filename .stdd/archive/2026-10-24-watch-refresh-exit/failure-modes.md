# 失败模式核查

1. 范围：Core 新增 handler 工厂 + WatchBridge 调用点 + check.sh 守卫；协议、超时、文案、手机端回复未改。
2. 复现：平台 RED 为真机崩溃报告符号化；Core RED 为类型缺失编译失败，不是 trap 复现（已如实标注）。
3. 同类排查：SDK 头文件核对，HealthKit 回调均 NS_SWIFT_SENDABLE；WatchBridge 仅 sendMessage 一处。
4. 回退防护：Core 类型保护工厂；调用点由 grep 守卫，样例验证命中。
5. 非 Sendable 数据：只在回调队列读取 Data 后跨 actor。
6. 生命周期：[weak self]，WatchBridge 进程级存活。
7. 晚回/重复：requestID 守卫保持原顺序；Core 测试每次只取首个交付。
8. 隐私：崩溃报告仅提取异常类型与栈，原文件留 gitignored work/。
9. 真机：版本核对与用户反馈分开记录；锁屏启动失败如实记录。
10. 切页路径：SKIPPED（无报告，未单独验证）。
