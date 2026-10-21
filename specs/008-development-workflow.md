# 008 STDD 开发流程接入

## 范围

采用 leonai42/stdd 3.0.5，固定上游提交 b9a4af62b5f4fd2747884c0a61febbc341792ac2。此轮是现有项目初始化，保留 business-v1 规格、验收 ID 和测试作为已有基线。后续行为变更采用 Understand → Spec → Build → Deliver。

## 验收标准

- DEV-001：项目内提供可重复执行的 `./scripts/stdd`，CLI 源码及 MIT 许可入库，不依赖本机全局安装。
- DEV-002：初始化保留原 AGENTS.md 边界和 specs/，配置 Swift / Swift Testing 及现有检查命令；提供 Codex 项目技能入口。
- DEV-003：新变更位于 `.stdd/changes/`，按上游三道 Gate 记录真实用户确认；已有代码不补造历史 Gate、TC 或 RED 记录。真机未验收状态继续保留。
- DEV-004：项目质量命令增加 STDD 配置、固定源指纹和技能入口检查；仍运行原有规格和 Swift 测试。STDD 文档验证不等于业务测试通过。
- DEV-005：初始化及日常 CLI 不写全局注册表，不自动安装其他平台 hook，不自动上传经验或健康相关内容；升级通过 PR 审阅。

## 验证方式

执行 init、status、guard status；在 work/ 临时项目验证 new/validate 基础工作流；再次 init 确认现有规则与配置不被覆盖；执行 scripts/check.sh。无应用行为变化，无新增设备能力保证。
