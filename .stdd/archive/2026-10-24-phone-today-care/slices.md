# 手机今日关怀切片计划

## Dependency Graph Summary

CLI 依赖图：phone-today-care 为唯一零依赖能力，无环。实现按 1 → 2 串行。

## Slice Execution Plan

| # | 优先级 | 风险 | 工作量 | TC 覆盖 | 实现目标 | 依赖 |
|---|--------|------|--------|---------|----------|------|
| 1 | P0 | 中 | M | TC-PTC-001/002/003/004 | 纯展示模型、边界/缺失/时效测试 | 无 |
| 2 | P0/P1 | 高 | L | TC-PTC-002/004/005/006 | 生产卡片/详情/时钟、隔离 UI 测试、完整模拟器布局 | 1 |

## Rationale

先锁定原整数边界、0/nil 和时效契约，再接 SwiftUI。UI 切片是同一生产入口到详情的闭环，拆分会用测试副本证明导航，故保留为一个连贯切片。CLI structure delta 路径错误，采用本文件和逐文件 diff 人工结构追溯；经验命令缺 requests，使用已核对本地 EXP-013/014。规则目录 .stdd/rules 不存在，不伪称已读取；使用 Swift standards、AGENTS 和项目契约。quality 配置未启用覆盖率/SwiftLint，不引入额外门禁。
