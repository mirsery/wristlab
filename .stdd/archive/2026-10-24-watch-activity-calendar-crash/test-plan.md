# 活动摘要日期契约测试方案

## 一、测试策略
真实Apple谓词RED/GREEN优先于DTO；UTC/上海/纽约及DST纯合成日期。现有231项、生产组件配置回归保留。真机不清缓存、不导出健康记录。

## 二、详细测试案例
### 日期契约
| 字段 | 内容 |
| --- | --- |
| **ID** | TC-ACAL-001 |
| 对应Spec/优先级 | ACAL-001 / P0 |
| Arrange/Act | 生产summaryDateComponents传真实HKQuery谓词 |
| Assert | 原参数同异常RED；修后calendar/timeZone齐，谓词无异常，零授权/读取 |

### 日期边界
| 字段 | 内容 |
| --- | --- |
| **ID** | TC-ACAL-002 |
| 对应Spec/优先级 | ACAL-002 / P0 |
| Arrange/Act | UTC/上海/纽约近午夜、春秋DST日期 |
| Assert | era/year/month/day与clock相同，时区和Gregorian正确 |

### 保留缓存与真机
| 字段 | 内容 |
| --- | --- |
| **ID** | TC-ACAL-003 |
| 对应Spec/优先级 | ACAL-003 / P0 |
| Arrange/Act | 同包2402保留现有连接/缓存后前台普通启动 |
| Assert | 不再calendar异常；版本/安装/持续运行及用户反馈分别记，未验不报通过 |

## 三、执行矩阵
平台隔离宿主执行001/002、重复构造保护003的同因参数；003完整路径另在真机确认。Widget原5种与iPhone1种注册、完整Swift回归和Apple构建仍必跑。

## 四、回归风险
系统时区不能改为评分时区或UTC；纯谓词测试不能调用HKHealthStore；不吞异常、不静默关闭活动；安装必须版本号区别2401。手机取消先仅诊断。

## 五、顺序
单切片：真实SDK RED → 原行为提取/精确修正 → SDK GREEN → 三路审查 → 全量检查 → 同包2402真机复验 → Gate 3实际确认。
