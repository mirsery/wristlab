# 单切片S1

依赖：AnalysisClock提供明确Gregorian及系统时区；生产DailyActivityReader参数提取进入真实HKQuery。无其他能力/循环。标准模式，约6分，非安全变更；3TC/3个新增Apple宿主测试函数，完整ACAL003仍需真机。版本3.0.5一致。

先写平台测试；提取原行为不修calendar以重现真实NSException，之后仅补calendar/timeZone并保持原日。原231项Swift测试回归。CLIs dependency-graph已执行，structure默认路径仍失败；experience缺requests，手工复用EXP011“不以启动回执作稳定运行”和EXP008日期来源保护，不改上游。
