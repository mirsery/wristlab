# 自动运动规划与每日完成度：一手资料核对

核对日期：2026-10-22。以下竞品描述仅说明官方公开行为，不代表其效果经 Wristlab 验证；不记录用户健康数据。

## 竞品公开行为

| 产品 | 官方描述 | 可借鉴交互（Wristlab 自定选择） |
| --- | --- | --- |
| Apple Fitness+ | Custom Plans 根据活动偏好、时长及运动日期组织计划；自建计划可选每周日期、每日总时间、周期、活动类型，预览后创建，之后可替换活动。[官方指南](https://support.apple.com/en-gb/guide/fitness-plus/apdf222051d8/ios) | 先收集可执行条件，再显示周预览；用户确认后采用，保留替换入口。 |
| Fitbod | My Plan 收集目标、器械、每周频次或指定日期、单次时长和经验；官方称这些设置影响动作、训练量及强度。[My Plan](https://help.fitbod.me/hc/en-us/articles/34336407191191-My-Plan) | 区分目标与可用时间；偏好可编辑，调整时保留进展。其减脂相关文案是厂商定位，不作为本项目减脂效果依据。 |
| Garmin Coach | Garmin Run Coach 可设置目标或结束日期、训练和休息日；官方称每日训练会结合表现、恢复及健康指标调整，并依赖兼容设备收集数据。[Garmin 官方介绍](https://www.garmin.com/en-US/blog/fitness/garmin-training-plans-for-runners/) | 明确展示训练日与休息日、建议依据和数据不足状态。不能据此推断 Wristlab 的实验分数具有相同能力。 |

## 一般健康参考及其适用边界

- WHO 对 18–64 岁成年人给出的健康参考为每周 150–300 分钟中等强度有氧活动，或 75–150 分钟高强度活动（或等效组合），并每周至少 2 天主要肌群力量活动。这是群体健康参考，不能直接作为每个人的初始处方，也不是减重日期换算公式。[WHO](https://www.who.int/europe/news-room/fact-sheets/item/physical-activity)
- NIDDK 指出，运动结合健康饮食可能帮助体重管理；即使没有减重，规律活动仍可有健康益处。因此运动分钟完成度不能证明当天减脂成功。[NIDDK](https://www.niddk.nih.gov/health-information/weight-management/staying-active-at-any-size)
- NIDDK 的体重规划工具同时涉及热量及活动，并限定成年人，排除孕期、哺乳期使用；本轮不复现该模型，也不由目标公斤数和日期推导热量缺口或保证达标。[适用说明](https://www.niddk.nih.gov/health-information/weight-management/body-weight-planner)

## HealthKit 数据事实

- `HKWorkout.duration` 表示记录时长，并考虑 `workoutEvents` 中的暂停区间；不能直接用 `endDate - startDate` 替代有效运动时长。[duration](https://developer.apple.com/documentation/healthkit/hkworkout/duration)、[workoutEvents](https://developer.apple.com/documentation/healthkit/hkworkout/workoutevents)。网页正文需要 JavaScript，本次同时核对本机 Apple SDK 一手声明：`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/HealthKit.framework/Headers/HKWorkout.h` 第 97–119 行。
- workout events 可表示暂停与恢复：暂停切换为 inactive，恢复切换为 active；重复的同状态事件不改变状态。[HKWorkoutEvent](https://developer.apple.com/documentation/healthkit/hkworkoutevent)

## 本轮建议的产品规则（自定，待规格确认）

- 将结果称为“运动计划完成度”；体重目标及日期单独展示。不得显示“今日减脂达标”或“按此运动必定按期减重”。
- 自动规划根据用户选择的活动、可用日期、时间和经验生成可调整周安排。公开规则、版本和原因；任何预设分钟数均是产品模板，不宣称经过科学验证的个体处方。
- 目标日期用于计划周期与长期进展参考，不能因为日期临近或体重反弹自动增加运动量；下一周调整应可预览并由用户采用。
- 每日统计保留计划分钟、读取到的有效运动分钟和手动确认的来源差别；空读取表示未读到记录，不能证明未运动或权限拒绝。
- 原始有效时长用 `HKWorkout.duration`；跨午夜归属、重叠记录去重、手动与自动完成合并需在规格内明确。不能从起止时间推算暂停发生在哪一天，无法可靠分配时须披露限制。
- 恢复数据缺失或过期时使用已确认计划并说明缺少依据；低恢复状态提供休息或轻量替代，不通过实验准备度直接计算训练剂量。

本文件是调研证据与设计建议，不构成新增算法规格，也不证明医疗有效性。
