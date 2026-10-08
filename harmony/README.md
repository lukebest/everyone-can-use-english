# Enjoy for HarmonyOS

Stage 模型工程（API 26 / HarmonyOS 26.0.0）。用 DevEco Studio 打开 `harmony/` 目录，签名后安装到手机。

课程、跟读、对话、生词都在这个应用里。查词、翻译、分析、润色、对话走 [`relay/`](../relay/)：模型是 Cursor SDK 的 `auto`，用量记在你的 Auto 池。手机上只保存中转地址和访问 Token。

## 课程资源

发音课来自 `1000-hours/sounds-of-american-english`。生成内置页面和音频：

```bash
cd harmony
npm install
npm run build:course
```

输出在 `entry/src/main/resources/rawfile/course/`（已加入 `.gitignore`）。课文在 ArkWeb 里打开，点读按钮播放 rawfile 音频，划词后点「查词」。

## 中转

先按 `relay/README.md` 启动服务。在应用的「我的」里填写 `http://<电脑局域网 IP>:8787` 和 `RELAY_TOKEN`。明文 HTTP 已在 `network_config.json` 里打开，只适合你自己的中转。

英文朗读用系统 Core Speech Kit 的 en-US 离线音色（劳拉，`person: 8`），需要在系统里下载英语语音。系统语音识别目前不支持英文，所以「自动分句」和「评分」走中转上的 whisper.cpp。

## 许可

仓库是 GPL-3.0-only，这个应用也是。`new-edition-drafts/` 里作者保留版权的媒体没有打进应用。
