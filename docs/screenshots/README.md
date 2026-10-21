# 应用截图 / Application captures

`iphone.png`和`watch.png`来自CI运行的原生SwiftUI应用，启动参数为`--demo`。数据为DemoData构造的合成记录，由正式HealthEngine计算；不是人工填入的真实健康数据，也不是设计概念图。

CI uses `scripts/capture-screenshots.py` to install and launch both simulator apps with `--demo`. Images show synthetic input processed by the production business engine. They do not verify real-device sensors, background delivery, signing or complication installation.

`manifest.json`记录模拟器名称、截图来源及生成run。应用源码变化后会重新生成；仅文档/测试变动时，CI核对应用源码指纹与图片SHA256并复用已验收截图。manifest保留最初生成run，不伪称复用时重新运行过应用。不用图片编辑代替实际渲染。

重新生成：在具备完整Xcode及两个平台模拟器的Mac运行`./scripts/build-apple.sh`，再运行`python3 scripts/capture-screenshots.py`，输出位于`work/screenshots/`。CI上传同名artifact供下载验证后入库。
