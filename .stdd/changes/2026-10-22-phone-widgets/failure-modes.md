# 失败模式检查（a–l）

| 类别 | 结果 |
| --- | --- |
| a 幻觉行为 | 已查：外观TC无渲染证据，明确标为待真机。 |
| b 范围蔓延 | 已查：只复用快照，不新增计算；CI超时调整写入设计。 |
| c 级联错误 | 已查：DashboardModel四处发布统一走publish()，Watch路径不变。 |
| d 上下文丢失 | 已查：design与实现不一致处（整体状态、准备度环）已更正。 |
| e 工具误用 | 发现并修正：注册检查CP原写check.sh（ADJ在scaffold修正为build-apple.sh）。 |
| f 运行时偏差 | 已查：注册期插值名称fatal由iOS宿主复现并拦截（EXP-20261021-002）。 |
| g 管线断链 | 已查：build-apple.sh串联watchOS与iOS检查。 |
| h 内容质量偏差 | 发现并修正：浅色模式原因文字不可见（ADJ-001）。 |
| i 指令衰减 | 已查：演示不写入；锁屏privacySensitive；不提交签名。 |
| j 覆盖真空 | 发现并修正：空的超限测试与缺失的单项状态（ADJ-003）。 |
| k 契约断层 | 已查：DisplaySnapshot未改；32KB与decode一致。 |
| l 锚定缺失 | 已查：显示复用ComplicationPresentation/Timeline。 |
