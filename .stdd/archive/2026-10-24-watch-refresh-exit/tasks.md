# 修复任务

- [x] S1：TC-WRX-001/002 Core 测试 RED（work/watch-exit-core-red.log）→ `WatchRefreshHandlers` → GREEN（work/watch-exit-core-green2.log）→ WatchBridge 接入；check.sh 调用点守卫。
- [x] 三路只读评审、check.sh 256 项、build-apple.sh 退出 0。
- [x] 2406 同包覆盖手表并核对版本 2406（手表锁屏，自动启动被拒 Locked，未代为启动）；不清数据；覆盖前崩溃目录基线 work/watch-exit-crash/baseline-before-2406.txt。
- [ ] 用户真机刷新/切页反馈 + 崩溃目录复核（WRX-003），Gate 3。
