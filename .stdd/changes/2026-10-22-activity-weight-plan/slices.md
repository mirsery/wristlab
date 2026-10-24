# 切片执行与依赖

CLI dependency-graph：activity-plan、weight-goal，无循环。
A规则中风险→B存储/体重高风险→C界面中风险→D验证，串行落地。
A新增计划和建议测试；B补迁移、写失败、revision、DST与体重聚合测试；C只做实现及静态/编译检查，不把未执行的UI TC标为done。
新增13个测试函数；完整8TC尚待界面验收，保留Build in_progress。
