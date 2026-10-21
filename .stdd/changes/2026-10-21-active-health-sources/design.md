# 活跃健康来源选源修复（Gate 1/2已确认，实施中）

## Context

规范记录保留150日，评分只在最近60个分析日形成basis/压力桶。当前先对150日全部记录选源，再过滤计算窗口；旧设备会因此遮挡新设备的实际输入。合成复现命令为 `swift run --package-path work/source-selection-probe SourceSelectionProbe`。不使用真实记录做夹具。

## Decisions

RecordNormalizer.selected新增可选sourceWindow，用有效样本end是否落在闭区间判定自动候选组；显式preferredSources中仍有保留记录的组保留优先权。窗口内来源仍按rank/group排序。选定后返回同组完整保留历史，不逐日/逐桶改源。HealthEngine为HR/RHR/HRV显式传入固定分析时区下D-60午夜至asOf，同一revision使用同一窗口。睡眠与workout现有选源保持不变。

备选：按最新样本或逐桶改源，容易混合来源与基线，拒绝；删除旧数据会丢失历史，拒绝；把所有来源合并会重复/混基线，拒绝。14日基线、压力公式、时效与电量覆盖/断链规则不变，不为出分放宽门槛。

## Architecture

有效规范记录 → 窗口内候选组/显式偏好 → 固定单来源完整历史 → HealthEngine全量重算 → HealthRepository.sourceSignature变化推进epoch → 手机与Watch同一最小快照。

## Risks / Trade-offs

原先受影响的报告可能修订，能否出分取决于真实历史与覆盖。选源变化不得沿用旧基线或电量检查点；现有全量重放与epoch规则做集成回归。手动指定失活来源仍可缺失，尊重明确意图。当前60日之外的历史并不作为自动候选的依据，但选中组的完整记录仍保留。昨晚睡眠窗口直接读取为空属于独立待核对问题。

## 用户追加：缺失原因可见（Build期间明确授权）

用户原文：“但是要有提示给用户告知原因”。在既有来源修复上补齐解释，不改变数值公式、门槛或睡眠窗口。无电量seed时，HealthEngine保留实际夜间准备度失败的基线天数与availability；已完成主睡眠但夜间HRV/RHR缺失时分别标识，不再一律归因missingPrimarySleep。校准已有X/14有效历史日时明确显示原因及可做操作，不能承诺经过14个自然日必出分。

新增共享纯模型MetricExplanation，由手机卡片/详情和Watch首页/详情共用；组件保留简短状态，并可用同模型具体区分不足原因。页面直接显示原因，详情显示操作建议；无快照/清除/过期优先于历史不足，未知码中性回退，空读不能断言权限被拒。同步schema不新增字段，沿用reasons/availability/baselineDays。无数字替代缺失值，真实零保持。
