# 晨报本地通知 - 技术设计（Gate 1/2已确认，实施中）

## Context

应用已注册HealthKit观察者并启用hourly后台送达；每次真实刷新得到当天报告。睡眠报告在主睡眠为已完成episode（末次asleep距asOf≥90分钟、实际睡眠≥180分钟）时给出primary。设置页目前只编辑HealthProfile，而HealthProfile变化会推进版本并全量重算。

## Decisions

### 1. Core的MorningBrief只做判定与文案
**方案**：`MorningBrief.make(report:lastSentDay:hideValues:now:)`在报告为真实来源、报告日是当前分析日、今天有已完成主睡眠、当前处于分析时区05:00–14:00、当天尚未发送时返回`dayKey`、标题与正文。正文：准备度有值时为数值与002分段（日间回退/部分估算另标），否则为MetricExplanation的具体原因；加上主睡眠时长（primary.asleepMinutes，不含小睡）。隐藏数值时只提示“主睡眠已汇总”，不含任何数值或原因。
**为什么**：判定可单测；与首页同一套解释，不新增口径；不写任何建议。

### 2. 偏好放在本机UserDefaults
**方案**：`morningBriefEnabled`（默认关）、`morningBriefShowValues`（默认false，即隐藏数值）、`morningBriefLastDay`。设置页新增“晨报通知”分区，开启时请求通知授权，拒绝则保持关闭并说明。
**为什么**：放进HealthProfile会触发评分重算；通知偏好与评分无关。

### 3. 投递
**方案**：DashboardModel在真实刷新成功后调用`deliverMorningBrief(report:now:token:)`：检查开关与授权，await后再核对generation，生成MorningBrief，先记下当天再以`morning-brief-<分析日>`立即投递，失败则回滚。AppDelegate作为通知代理，前台也显示（banner+list）。清除数据撤回已送达与待发晨报。设置页出现时检查授权，事后被关闭时提示。演示路径不调用。
**为什么**：复用已有后台唤醒；以本地记录去重（同标识通知不能防重复提醒）。不承诺固定时间。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 锁屏露出健康数值 | 默认隐藏数值 |
| 深夜或重复推送 | 仅05:00–14:00、今天主睡眠完成后、每个分析日一次，先记下再投递 |
| 前台被系统静音 | 通知代理返回banner+list |
| 清除后仍留有数值 | 清除时撤回已送达与待发晨报；await后核对generation |
| 后台机会不确定 | 文案与设置说明不固定送达时间；打开应用时也会检查 |
| 授权被拒 | 保持关闭并说明，不反复请求 |
