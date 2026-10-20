# 应用截图 / Application captures

`iphone.png`和`watch.png`来自CI运行的原生SwiftUI应用，启动参数为`--demo`。数据为DemoData构造的合成记录，由正式HealthEngine计算；不是人工填入的真实健康数据，也不是设计概念图。

CI uses `scripts/capture-screenshots.py` to install and launch both simulator apps with `--demo`. Images show synthetic input processed by the production business engine. They do not verify real-device sensors, background delivery, signing or complication installation.

`manifest.json`记录模拟器名称、截图来源及生成run。UI变更后需重新生成，不用图片编辑代替实际渲染。

重新生成：在具备完整Xcode及两个平台模拟器的Mac运行`./scripts/build-apple.sh`，再运行`python3 scripts/capture-screenshots.py`，输出位于`work/screenshots/`。CI上传同名artifact供下载验证后入库。
