# STDD 项目使用说明

本项目已执行 leonai42/stdd 3.0.5 的 init 和 Codex install，固定源见 [upstream.json](../.stdd/upstream.json)。CLI 源码原样随库保存，MIT 许可证见 [vendor/LICENSE](../.stdd/vendor/LICENSE)。项目契约见 [STDD_CONSTITUTION.md](../STDD_CONSTITUTION.md)。

## 命令

从仓库根目录执行：

```sh
./scripts/stdd --project-check
./scripts/stdd status
./scripts/stdd new improve-sleep --task-type code
./scripts/stdd status improve-sleep
./scripts/stdd validate improve-sleep
./scripts/check.sh
```

没有 active change 时，status 提示“找不到 change”属于初始化后的正常状态。new 只创建草稿；proposal.md 由 canonical YAML 渲染，模板未填写前 validate 可能失败，不能当作完成记录。

首次调用会在 work/stdd-venv 创建 Python 隔离环境并安装固定 PyYAML 6.0.3；需要 Python 3.10+ 及首次联网。此依赖只用于开发流程，不进入 iOS/watchOS 应用。Python 证书异常时应修复受信 CA，保持 TLS 校验；本机安装使用现有 Homebrew CA 包成功。

## 四阶段与 Gate

1. Understand：创建 change、填写 canonical proposal，用户确认范围后记录 Gate 1。
2. Spec：填写设计、GIVEN/WHEN/THEN 规格和 TC 测试计划，用户确认后记录 Gate 2。
3. Build：逐切片 RED/GREEN/REFACTOR，记录失败模式检查、测试报告和设计偏差，用户确认后记录 Gate 3。
4. Deliver：检查通过后归档，更新文档并通过 PR 合并。经验保存在本地，社区发布需要另行明确授权。

进入阶段时读取 `.stdd/skills/` 对应文档。Codex 入口在 `.agents/skills`，链接到上游 installer 生成的 `.codex/skills`。当前会话未必自动重载技能目录；可直接读取项目技能，重新打开项目后再检查技能发现。

上游命令示例中的 `python bin/stdd` 或裸 `stdd` 统一替换为 `./scripts/stdd`。CLI 不会代用户批准 Gate；批准命令仅在实际获得当前 Gate 确认后执行。

## 已有规格迁移

接入前 business-v1、47 项产品验收、31 个场景与已有测试保留在根目录 specs/ 及 Packages/、Tests/。本次不生成伪造的历史 Gate、TC 映射或 RED 证据。

新 change 采用 `.stdd/changes/` 和 canonical YAML。新归档规格位于 `.stdd/specs/`；修改已有业务行为时，同时更新原 specs/ 权威定义并引用原验收 ID / SCN，避免两套定义相互矛盾。旧行为可随实际修改逐步迁移，不能仅凭结构检查宣称全部追溯完成。

## 项目适配

- 上游 CLI 源码保持原样，项目 wrapper 重定向注册表到 gitignored work/stdd-projects.yaml。
- init 仅设置 Codex 的 AGENTS.md 标记，不安装 Claude hook、不自动拉社区经验。Guard 是代理规则，不是操作系统写入拦截。
- 保留三道 Gate，包括轻量模式；关闭轻量模式默认自动通过 Gate 2，任务类型命令也映射到 Swift 与现有检查。长程执行仅按用户明确授权启用。重大设计偏差暂停确认。
- Swift / Swift Testing 使用现有 check.sh 和 build-apple.sh；未引入 pytest、ruff 或未经执行的覆盖率门槛。
- init 上游仅复制一个共享片段，项目补齐所有共享片段、模板和 Swift 参考规范。Swift 参考规范不是已安装 SwiftLint 的声明，实际门禁以项目命令为准。
- 上游 installer 对已有 frontmatter 重复包装；wrapper 生成单一 frontmatter，并添加项目契约入口。
- 自动升级和社区发布被 wrapper 拒绝；升级通过单独 PR 检查固定来源及本地适配。

## CI 的实际保证

Core and specs 的原有 check.sh 增加 `./scripts/stdd --project-check`，校验固定上游源码摘要、YAML 配置、Gate 开关、技能入口及活跃变更的阶段结构。进入 Build/Deliver 的 change 需有前序 confirmed_at；时间戳不证明用户确实确认，评审仍需核对证据。

现有 Swift 测试和 Apple 构建继续执行。空 change 集合意味着尚未开始新任务，不表示历史全部符合 STDD，也不表示真机验收通过。
