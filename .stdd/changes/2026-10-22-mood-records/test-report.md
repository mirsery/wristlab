# 心情记录与压力对照：Build 测试报告

2026-10-22；分支feat/mood-records（叠在feat/long-trends上，#8合并后rebase到main）。Xcode 27.1，iPhone 18 Pro模拟器（iOS 27.1）。Gate 1/2已确认（本批授权），Gate 3待用户真机验收。

## 结果

- `./scripts/check.sh`：83 Core + 5 workspace通过；`./scripts/build-apple.sh`：双端与Widget注册运行通过；`git diff --check`通过。RED为缺接口编译失败（work/mood-red.log）。
- HKStateOfMind接口与枚举按本机SDK（iOS 27.1）头文件与swiftinterface核对：iOS 18起可用，classification 1–7、labels 1–38、associations 1–18、`.stateOfMind`谓词。

| TC | 结果 | 证据 |
| --- | --- | --- |
| MOOD-001 | 通过 | 完整中文表按SDK顺序、越界“未知” |
| MOOD-002 | 通过 | 包含桶/边界/0、15、16分钟/无值桶/不借之后的桶/运动标注；上海半开日跨午夜、偶数中位数取整；时间线7个分析日且下界正确；当前压力不变 |
| MOOD-003 | 通过 | 7日窗口、未来、去重、倒序、上海与纽约夏令时边界、当天标记、截至目前与晚于报告 |
| MOOD-004 | 部分 | 有记录态模拟器截图（合成心情、压力图虚线标记、图例、声明）；未连接、无记录、iOS 17隐藏仅静态检查，待真机 |

## 复审（C1）

三路复审完成；实测bug（每日心情跨午夜）、并发与停止读取、标注与措辞、时间线下界均已处置（ADJ-001～004）；测试复审6个存活变异补测后全部抓住。

## 缺口

- 真机：授权弹窗、真实State of Mind读取、三种卡片状态、iOS 17设备隐藏未验证。
- 心情只在内存，断网/重启后需刷新重新读取（设计如此）。
