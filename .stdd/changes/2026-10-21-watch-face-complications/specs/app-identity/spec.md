# Spec: app-identity

> Change: 2026-10-21-watch-face-complications | Auto-generated Human View

## Requirements

### Requirement: 已确认图标接入双端

#### Scenario: SC-ICON-001

- **GIVEN** 用户已确认薄荷绿W图标母版
- **WHEN** 生成应用图标和工程配置
- **THEN** SHALL 沿用同一图案与颜色生成不透明1024平方母版及平台所需Asset Catalog，不预烘焙外部圆角；两个target选择AppIcon，三个Apple目标构建通过

### Requirement: 可达的表盘安装说明与独立预览

#### Scenario: SC-ICON-002

- **GIVEN** 手机设置页或Watch更多菜单
- **WHEN** 打开表盘组件说明
- **THEN** SHALL 展示四种组件选择、手机Watch App或手表长按表盘后编辑复杂功能的步骤，并明确槽位由所选表盘决定；无有效.watchface资源时不显示一键添加承诺

#### Scenario: SC-ICON-003

- **GIVEN** 说明页展示准备度89、电量76、压力39的示例
- **WHEN** 查看预览及公开截图
- **THEN** SHALL 始终标注合成演示，不把样例写入同步/真实快照；中英文README和验证记录区分预览、模拟器运行及真机验收
