# Spec: icloud-data-center

> Change: 2026-10-22-icloud-data-center | Auto-generated Human View

## Requirements

### Requirement: 当前iCloud账户的非健康界面偏好同步、恢复及隔离。

#### Scenario: SC-CLOUD-001

- **GIVEN** 账户状态或应用配置不同
- **WHEN** 查看数据中心
- **THEN** SHALL区分账户可用性与同步完成，不伪造Apple ID身份，未配置不发无效请求。

#### Scenario: SC-CLOUD-002

- **GIVEN** 界面偏好及健康/计划/体重合成数据
- **WHEN** 主动开启并上传
- **THEN** SHALL默认关闭，说明后只序列化四字段及版本元数据，演示与健康数据不上传。

#### Scenario: SC-CLOUD-003

- **GIVEN** 首次启用或服务端并发/未知版本
- **WHEN** 恢复或上传偏好
- **THEN** SHALL先读并明确选择，服务器版本检测冲突，未知schema不覆盖。

#### Scenario: SC-CLOUD-004

- **GIVEN** 旧账户请求或队列尚未完成
- **WHEN** 账户变化、关闭或回调返回
- **THEN** SHALL以账号环境和generation失效旧任务，不跨账户同步或把身份未知当作新账户。

#### Scenario: SC-CLOUD-005

- **GIVEN** 离线/服务失败/重启或新机健康历史未到
- **WHEN** 编辑和重试
- **THEN** SHALL保留本地及原账号队列，准确标待同步，成功时间只在确认后更新，不宣称完整健康恢复。

#### Scenario: SC-CLOUD-006

- **GIVEN** 云偏好、本地副本和旧设备待传任务
- **WHEN** 关闭或清除本机/云端
- **THEN** SHALL区分清除范围，删除标记阻旧副本静默复活，云未确认不报成功，健康原始不删除。
