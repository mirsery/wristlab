# Build进度

Gate 1用户“确认，按这个范围修复”；Gate 2用户“确认，实施这个修复方案”。已捕获真实NSInvalidArgumentException缺calendar；未导出健康容器/记录，仅留过滤后的异常元数据。2401两端已安装并核对版本；解锁后启动回执成功，但Watch反复闪退，因此不得记为功能验证通过。手机用户状态“无数据，刷新已取消”，未发现同一异常，另行诊断。

生产日期构造已先提取保留原错误，真实SDK平台宿主在272ms内抛出与真机相同NSInvalidArgumentException，work/calendar-crash-platform-red.log。补calendar/timeZone后同一宿主3个合成谓词测试和5组件注册GREEN（work/calendar-crash-platform-green.log），无授权或读取。三路只读审查无阻断，明确ACAL003 CONTRACT不等于真机完整通过。用户随后再次明确“这个确认这个方案”，Gate 2前次真实确认仍保留，不重复改时间。

scripts/check.sh退出0（196 Core+35 workspace=231），scripts/build-apple.sh双端构建+3日期契约+5Watch/1iPhone配置注册退出0。generic iOS包含Watch/两组件2402签名构建及四包版本/签名/组/只读HealthKit/默认无云校验通过。设备尚未覆盖修复版：两次Watch安装被4016拒绝，设备调试列表手机disconnected、Watch unavailable，已请求重新连接/解锁；不得把2401安装成功记成2402成功。Gate 3未批准。

手机用户补充“无数据，刷新已取消”“点连接没反应”。进程查询曾见主进程，定向崩溃文件名查询0条；没有复现Watch同一异常。一次LLDB附加未成功（Process must be launched），未读取busy/status或任何健康内容；后续调试器设备列表确认手机disconnected。暂不能断言busy锁死、拒绝授权或数据缺失，手机源码未改。已询问按钮是否灰色/转圈，另请求恢复连接。默认云关闭，不清数据/卸载。

三路只读评审全部返回无确定阻断，均强调ACAL003仅CONTRACT通过，完整真机必须另验。新增测试有效性：生产helper直接传真实HKQuery，原calendar缺失异常RED，修后GREEN；不初始化HKHealthStore、不授权或读记录。全量失败模式与详细证据见test-report.md和failure-modes.md。

用户“再试试”后：Watch安装报RemotePairing1001；改完整包同包覆盖手机成功sequence2180，实际核对0.1.0（2402）、普通启动成功，后续仍见主进程。手机内嵌Watch修复包不证明Watch更新：Watch查询报1035，devicectl manage pair返回paired后再次安装仍报1035，停止盲目重试，未unpair或清数据。手机用户确认按钮正常可点但无变化；三次LLDB诊断未取得busy/status，已终止本次挂起调试器并普通重启App，无调试器继续占用。手机健康读取未证实恢复，手表2402安装/稳定性/真实刷新未验，Gate3不批准。最新证据见test-report.md。

用户重启手表后再试：work/calendar-crash-watch-postreboot-install.log仍1035，xcdevice仅手机available=true、手表available=false（局域网浏览中）；info details超时。用户又报“手表不行”，未将修复版视为已装。手机仍无反馈，用户另行批准手机修复Gate1，转新变更2026-10-24-phone-health-connection；不把手机新增修复合并冒充本change原范围。默认iCloud关、未unpair/卸载/清数据。

开发连接随后恢复：实际查到旧2401，覆盖2402成功sequence1000，核对0.1.0（2402）、普通启动与延迟主进程存在。用户对切页/活动刷新是否闪退的询问回复“不再闪退，页面可打开”。最终本轮启动/切页修复已有真机反馈，表盘/后台/性能、各活动值未全验；手机2404用户“已更新本地报告”归独立PHC变更。Gate3最终报告确认尚未记录，不把功能状态回复代批完整报告。

交付最终状态：最终报告披露两故障范围与平台缺口后，用户明确“确认，本轮修复验收并本地归档”，CLI记录Gate3；本change已本地归档，canonical原文及合并活动基线保留，WDA001–005未丢失。Deliver completed，不提交/tag/push，不上传经验或跨项目知识图谱；先前“未批准/待验收”段落为进度历史，不能覆盖本次实际确认，未验项仍不追认为通过。
