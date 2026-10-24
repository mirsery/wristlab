# 文档草案验证记录

- README中英文均嵌入docs/feature-dashboard.svg；中文增加五Tab任务导航、计划/体重功能说明和优化文档入口，保留原有运行截图。
- SVG XML、自包含检查与三个文档的本地链接检查通过；无script、foreignObject或外部图片资源。
- IAB打开本机SVG，完整截图目视核对：五Tab、三项状态、睡眠、周安排、趋势、本地控制和跨端功能全部可见，中文与免责声明未见截断。仅验证文档图形，不是App交互验证。
- Quick Look产生的缩略图错误裁切，未用作最终证据；独立Playwright预览超时，改用本机IAB成功，未伪称所有预览工具通过。
- work/readme-dashboard-check.log：scripts/check.sh通过，129个Core＋5个workspace测试，共134；git diff --check、scripts/stdd --project-check通过。
- 未修改应用目标，不重复Apple构建和设备安装。未提交。新change保持Understand草案，未记录任何未经确认的Gate；页面优化仅为建议，不是已实现布局。

后续建议：先确认活动首屏入口整合的交互与验收，再独立进入App变更流程；手机大字体、滚动、安全区等仍需真实交互验证。
