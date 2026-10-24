# 失败模式实际核查（2026-10-24）

| 类别 | 实际检查和结果 |
| --- | --- |
| 1 范围漂移 | 人工逐项核对3能力/9需求/15场景；仅本轮文件，综合周报未实施；其他本地修改保留。 |
| 2 TC遗漏/虚假覆盖 | 15个TC有Swift生产路径引用，详见test-report；Python-only扫描仍报0/15，未改上游或伪造覆盖。完整UI场景未通过。 |
| 3 规格语义/锚定 | CLI唯一TC/SHALL/AND/3能力检查通过；人工对照原独立Watch主动连接、停止标记和原子store，EXP008日期代次规则已复用。 |
| 4 缺失/零/未知目标 | Core实际测试0与nil、非法/重复日期、未知/非正目标、超额封顶、暂停不祝贺；无默认30/12或10000步。 |
| 5 时效/日期/时区 | 60分钟/未来/非当日拒当前，午夜预排失效；25小时DST与协调器日期/时区变化晚回测试通过；真实系统时区切换SKIPPED。 |
| 6 授权误判/额外读取 | fake未连接前0授权0读取；生产白名单仅stepCount/activitySummary、toShare空，无新增后台/运动会话；真实授权返回SKIPPED。 |
| 7 分项失败/时间洗新 | 步数失败保留原值/原时间、圆环独立成功；反向失败保留真实exercise12及原时间，实际协调器测试通过。 |
| 8 原子写失败/重开 | 私有writer失败保留文件/内存，损坏文件保留；共享投影writer失败保留旧包，重开一致；合法JSON40000成功/40001拒绝。 |
| 9 晚回/停止/恢复 | 合法999步晚回被拒、busy收束；投影恢复清旧notice；全清失败保持持久cleanupPending、重开阻止care，恢复清理不自动读取。 |
| 10 跨系统/来源一致 | App/Widget读同一已提交包；context携producer/epoch/sequence/config/zone/asOf、切phone清趋势；await后取最新envelope。竞争测试曾RED复现，但不穷举调度。 |
| 11 隐私/清除/演示 | 心情仅私有当天一条，可改删；共享JSON无mood；旧generation演示提交零写入；phone clear保留local care，全清实际回调清care。未导出健康数据。 |
| 12 评分/Agent CP | 原公式/版本未改，196 Core+35 workspace完整GREEN；CP-CARE-1/2/3的check/build/diff实际执行。不是医疗估算验证。 |
| 13 UI/组件 | 真实合成SwiftUI首屏观察发现并修复更多按钮同色；5Watch+1iPhone生产配置运行PASS、旧路由保留。Crown/VoiceOver/全family/低亮度实际交互SKIPPED，不以静态代码替代。 |
| 14 依赖/签名/云/残留 | 无新增运行依赖；源文件无调试输出/TODO/try!；只读HK、默认云false，不提交签名/凭据，不操作真机。文件保护沿现有原子helper，锁屏行为SKIPPED。 |

coverage.json/Swift行分支覆盖未配置，SKIPPED，不将测试函数数当覆盖率。CLI对canonical的旧路径/能力提取限制仍保留原始日志。全部14类已进行实际代码/命令/测试核查；表中SKIPPED明确代表未完成的运行验证，不是通过。
