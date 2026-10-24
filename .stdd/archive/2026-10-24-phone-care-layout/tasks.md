# 修复任务

- [x] S1：TC-PCL-001/003 RED → 等高双列 + 状态栏背板 → 001–004 GREEN（001/002 见 work/care-layout/ui-green3.log，003/004 见 ui-green4-fullapp.log）；截图人工核对；两次变异（透明/无色背板）均被 PCL-003 拦截。
- [x] 三路只读评审（无 P0；P1 隐私夹具、P2 若干已修）、check.sh 256 项、build-apple.sh 退出 0（work/fix-2406-check2.log、fix-2406-apple.log）。
- [x] 2406 签名构建（无 iCloud 权限）同包覆盖手机，版本核对 2406，普通启动成功。
- [ ] 用户真机布局反馈，Gate 3。
