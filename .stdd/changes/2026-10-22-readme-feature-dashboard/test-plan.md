# 文档预览检查方案

- 验证SVG XML可解析，无脚本、外部资源或真实健康数据。
- 浏览器完整渲染SVG检查中文、五Tab、卡片和免责声明不截断；Quick Look裁切不能当作整图正确证据。
- 检查中英文README及新增建议文档中的本地链接和图片均存在。
- 对照PhoneDashboardView/AutomaticMovementViews/PlanningViews核对功能和入口，不把拟议分段导航写成已实现。
- 运行scripts/check.sh及git diff --check；仅文档，不要求重新安装或Apple应用构建。
- 用户确认前保持草案状态；不把文档示意标成已通过设备验收。
