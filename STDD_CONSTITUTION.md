# Wristlab STDD 项目契约

本项目采用 [leonai42/stdd](https://github.com/leonai42/stdd) 3.0.5。上游来源及代码摘要见 `.stdd/upstream.json`；项目适配见 `docs/stdd.md`。本文件定义项目采用方式，涉及隐私、命令及目录时优先于通用模板。

1. 新功能、修复和重构先创建 `.stdd/changes/<日期>-<名称>/`，按 Understand → Spec → Build → Deliver 执行。
2. Gate 1 确认范围；Gate 2 确认设计、行为规格和测试计划；Gate 3 确认实际验证报告和设计偏差。仅在用户实际确认后记录批准，不由代理代批。具体确认可来自当前对话，保留对应证据。
3. Build 使用 RED → GREEN → REFACTOR，维护切片、失败模式检查、TC 与规格/测试/实现映射。模拟器和真实设备验证分别记录。
4. 当前 business-v1 和测试是接入前的基线，初始化不代表历史 Gate、用例追溯或真机验收已经通过。后续修改的行为逐步建立 STDD 规格与 TC 映射；未修改行为仍由原 specs/ 权威定义。
5. `./scripts/stdd` 为 CLI 唯一项目入口；上游文档中的 `python bin/stdd` 和裸 `stdd` 均使用此入口。项目命令从仓库根目录执行。
6. 经验和知识仅保存在项目本地。交付阶段不自动上传经验、不自动发布 Issue/PR 到第三方社区。真实健康数据、个人签名和账号信息继续按 AGENTS.md 隔离。
7. Codex Guard 通过 AGENTS.md 和技能指引执行，是代理规则，不能声称是不可绕过的系统写入拦截。CI负责确定性检查，Gate确认的真实性仍需人工审阅。
8. STDD 初始化自身为用户授权的一次性配置引导，不追补虚构的审批记录。之后的变更遵循上述流程。
