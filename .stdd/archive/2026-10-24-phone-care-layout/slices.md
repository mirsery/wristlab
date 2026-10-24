# 单切片 S1

依赖：生产 `PhoneCareSection` / `PhoneCareCard`（宿主直接编译）与 `PhoneDashboardView.page(_:content:)`（正式 App）。无循环。标准模式；4 个 TC 均有 UI 自动化，其中 002/004 为修前即通过的回归保护。

先加 `--mixed-heights` 夹具与四个 UI 测试：修前 PCL-001 顶边 391 vs 457pt、PCL-003 状态栏偏差 26 RED（work/care-layout/ui-red-host.log、ui-red-fullapp.log），再改等高双列与今天页状态栏背板。
