# 设计调整

睡眠页用户反馈“顶部区域挡住内容”。移除列表外safeAreaInset固定pageStatus，改为List首个Section随内容滚动；状态日期/来源/演示退出保留，重复演示标记移除。这是原P-004/P-010的布局修正，不改业务数据；实际手机效果仍待验收。

无范围或接口偏离。小调整：活动卡称“报告日活动”，避免旧缓存误读为今天；下界提示同时说明尚未结算或覆盖不足。睡眠复用现有List并增加近期统计，设置继续使用sheet。

工具限制：canon generate --type spec仍只生成proposal，Gate 2已正确从YAML生成两份spec；experience CLI缺requests，读取本地经验文件替代；structure delta查找错误的changes/根路径，改以git diff --stat核对实际变更。
