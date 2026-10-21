# 晨报本地通知：Build 测试报告

2026-10-22；分支feat/morning-brief（叠在feat/phone-widgets上）。Gate 1/2已确认（本批授权），Gate 3待用户真机验收。

## 结果

- `./scripts/check.sh`：89 Core + 5 workspace通过；`./scripts/build-apple.sh`：双端构建与两个注册运行检查通过；`git diff --check`通过。Core RED为缺接口编译失败（work/brief-red.log）。

| TC | 结果 | 证据 |
| --- | --- | --- |
| BRIEF-001 | 通过 | 今天/已发/无主睡眠/非今天/演示/nil；05:00与14:00两侧；上海分析时区dayKey与UTC对照 |
| BRIEF-002 | 通过 | 数值与分段、日间与部分估算标注、校准中与过期原因、主睡眠不含小睡、隐藏模式无数字、无建议词 |
| BRIEF-003 | 未验证 | 静态检查；授权、前台/后台送达、锁屏显示、清除撤回待真机 |

## 复审（C1）

代码与测试/文档两路复审完成（本轮范围小，合并为两路），发现已处置（ADJ-001～004）。

## 缺口

- 通知授权与送达、前台展示、后台唤醒时机、Watch镜像均待真机。
