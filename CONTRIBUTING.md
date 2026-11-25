# 协作与 CI 规则

新功能、修复和重构先按[STDD 项目契约](STDD_CONSTITUTION.md)创建 change，使用[项目命令](docs/stdd.md)完成四阶段和三道 Gate。所有行为变化先更新 spec 和验收 ID，再提交实现；PR 描述列出覆盖的 ID 与证据。新增算法需同时更新公式与边界测试。注释、文档优先中文，Swift 类型和 API 使用英文。

## 检查门禁

- `Core and specs`：文档结构与链接，共享模型和领域逻辑测试。
- `iOS and watchOS build`：生成工程，分别编译 iOS 与 watchOS 模拟器目标，关闭签名。
- CI 触发于 main push、PR 和手动执行；只读 token，不使用生产数据、签名证书或仓库 secrets。
- 截图采集是尽力而为步骤（失败不阻断作业，并打印模拟器日志）：CI 模拟器曾在代码不变时卡在启动应用。构建、测试与组件注册运行检查仍是必须通过的门禁；入库截图由 `check_specs.py` 核对。
- Actions 使用固定提交 SHA；Dependabot 每月更新。CI 使用 GitHub `xcode-27` 镜像并选用其中最新的正式版 Xcode 27；自用项目只支持最新 Xcode，不兼容旧版本；Homebrew XcodeGen 当前随 runner 安装，日志记录版本。若生成器漂移导致失败，应评估后固定版本。
- 模拟器编译不证明健康传感器、后台同步、表盘刷新、小组件刷新、通知送达或真机安装可用；这些项目在 PR 单独记录手工验收。

## 分支策略

`main` 保持可编译，功能通过短期分支和 PR 合并；合并前两个 CI 检查必须通过，处理所有未解决 review。
建议仓库 ruleset：禁止 force push 和删除 main，要求 PR、两个 required checks、会话已解决；单人自用仓库不强制他人审批。
规则配置源文件为 `.github/rulesets/main.json`。初始化完成后通过 GitHub API 创建并验证其 active 状态；后续规则变化同时更新文件与远端 ruleset。仓库只允许 squash merge，合并后自动删除分支。

## Review

检查 spec 对齐、数据来源、缺失/过期状态、算法版本与隐私边界。Review 任务只报告问题，除非用户同时要求修改。提交使用 `feat:`, `fix:`, `docs:`, `ci:`, `chore:` 前缀。
